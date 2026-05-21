import AppKit
import AVFoundation
import Combine
import Speech

struct DictationHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let date: Date

    init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
}

struct DictationLocale: Identifiable, Hashable {
    let id: String
    let name: String
}

final class DictationStore: ObservableObject {
    static let locales: [DictationLocale] = [
        DictationLocale(id: "en-US", name: "English (US)"),
        DictationLocale(id: "en-GB", name: "English (UK)"),
        DictationLocale(id: "es-US", name: "Spanish (US)"),
        DictationLocale(id: "fr-FR", name: "French"),
        DictationLocale(id: "it-IT", name: "Italian"),
        DictationLocale(id: "de-DE", name: "German")
    ]

    @Published private(set) var isRecording = false
    @Published private(set) var isFinishing = false
    @Published var liveTranscript = ""
    @Published var lastTranscript = ""
    @Published var errorMessage: String?
    @Published var speechPermission = SFSpeechRecognizer.authorizationStatus()
    @Published var micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published var history: [DictationHistoryItem] = []
    @Published var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) }
    }
    @Published var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Keys.copyToClipboard) }
    }
    @Published var smartCleanup: Bool {
        didSet { defaults.set(smartCleanup, forKey: Keys.smartCleanup) }
    }
    @Published var selectedLocaleIdentifier: String {
        didSet { defaults.set(selectedLocaleIdentifier, forKey: Keys.locale) }
    }
    @Published var launchAtLogin: Bool = LaunchAtLogin.isEnabled {
        didSet { LaunchAtLogin.setEnabled(launchAtLogin) }
    }

    var permissionSummary: String {
        if speechPermission != .authorized {
            return "Speech Recognition permission is needed."
        }
        if micPermission != .authorized {
            return "Microphone permission is needed."
        }
        return "Ready for dictation."
    }

    private enum Keys {
        static let autoPaste = "Whisp.autoPaste"
        static let copyToClipboard = "Whisp.copyToClipboard"
        static let smartCleanup = "Whisp.smartCleanup"
        static let locale = "Whisp.locale"
        static let history = "Whisp.history"
    }

    private let defaults = UserDefaults.standard
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingStartedAt: Date?
    private var finishWorkItem: DispatchWorkItem?

    init() {
        autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        copyToClipboard = defaults.object(forKey: Keys.copyToClipboard) as? Bool ?? true
        smartCleanup = defaults.object(forKey: Keys.smartCleanup) as? Bool ?? true
        selectedLocaleIdentifier = defaults.string(forKey: Keys.locale) ?? "en-US"
        history = Self.loadHistory(from: defaults)
    }

    func requestPermissions() {
        speechPermission = SFSpeechRecognizer.authorizationStatus()
        micPermission = AVCaptureDevice.authorizationStatus(for: .audio)

        if speechPermission == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.speechPermission = status
                }
            }
        }

        if micPermission == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
                }
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        errorMessage = nil
        finishWorkItem?.cancel()

        speechPermission = SFSpeechRecognizer.authorizationStatus()
        micPermission = AVCaptureDevice.authorizationStatus(for: .audio)

        guard speechPermission == .authorized else {
            requestPermissions()
            errorMessage = "Turn on Speech Recognition for Whisp in System Settings."
            return
        }

        guard micPermission == .authorized else {
            requestPermissions()
            errorMessage = "Turn on Microphone access for Whisp in System Settings."
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLocaleIdentifier)),
              recognizer.isAvailable else {
            errorMessage = "Speech Recognition is not available for \(selectedLocaleIdentifier) right now."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            errorMessage = "No microphone input was found."
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "Whisp could not start the microphone: \(error.localizedDescription)"
            return
        }

        audioEngine = engine
        recognitionRequest = request
        liveTranscript = ""
        recordingStartedAt = Date()
        isRecording = true
        isFinishing = false

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognition(result: result, error: error)
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        isFinishing = true

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishRecording(with: self?.liveTranscript ?? "")
        }
        finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    func cancelRecording() {
        finishWorkItem?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        isRecording = false
        isFinishing = false
        liveTranscript = ""
    }

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        ClipboardService.copy(lastTranscript)
    }

    func pasteLastTranscript() {
        copyLastTranscript()
        PasteService.paste()
    }

    func clearHistory() {
        history.removeAll()
        persistHistory()
    }

    func copy(_ item: DictationHistoryItem) {
        ClipboardService.copy(item.text)
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            liveTranscript = result.bestTranscription.formattedString
            if result.isFinal {
                finishRecording(with: liveTranscript)
            }
        }

        if let error, isRecording || isFinishing {
            let nsError = error as NSError
            if nsError.domain != NSURLErrorDomain {
                errorMessage = "Dictation stopped: \(error.localizedDescription)"
            }
            finishRecording(with: liveTranscript)
        }
    }

    private func finishRecording(with rawText: String) {
        finishWorkItem?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        isRecording = false
        isFinishing = false

        let cleaned = clean(rawText)
        liveTranscript = cleaned
        guard !cleaned.isEmpty else { return }

        lastTranscript = cleaned
        addHistory(cleaned)

        if copyToClipboard || autoPaste {
            ClipboardService.copy(cleaned)
        }

        if autoPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                PasteService.paste()
            }
        }
    }

    private func clean(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard smartCleanup, !cleaned.isEmpty else { return cleaned }

        let first = cleaned.prefix(1).uppercased()
        cleaned = first + cleaned.dropFirst()

        if let last = cleaned.last, !".!?".contains(last) {
            cleaned += "."
        }
        return cleaned
    }

    private func addHistory(_ text: String) {
        let item = DictationHistoryItem(text: text)
        history.insert(item, at: 0)
        if history.count > 25 {
            history = Array(history.prefix(25))
        }
        persistHistory()
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Keys.history)
        }
    }

    private static func loadHistory(from defaults: UserDefaults) -> [DictationHistoryItem] {
        guard let data = defaults.data(forKey: Keys.history),
              let items = try? JSONDecoder().decode([DictationHistoryItem].self, from: data) else {
            return []
        }
        return items
    }
}

