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

enum TextTransformation: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"
    case raw = "Raw"
    case bulletList = "Bullet List"
    case titleCase = "Title Case"
    case upperCase = "UPPERCASE"
    case snakeCase = "snake_case"

    var id: String { self.rawValue }
}

enum HotkeyModifiersCombo: String, CaseIterable, Identifiable, Codable {
    case controlOption = "Control + Option"
    case controlCommand = "Control + Command"
    case optionCommand = "Option + Command"
    case controlShift = "Control + Shift"

    var id: String { self.rawValue }

    var carbonModifiers: UInt32 {
        switch self {
        case .controlOption:
            return UInt32(0x1000 | 0x0800) // controlKey | optionKey
        case .controlCommand:
            return UInt32(0x1000 | 0x0100) // controlKey | cmdKey
        case .optionCommand:
            return UInt32(0x0800 | 0x0100) // optionKey | cmdKey
        case .controlShift:
            return UInt32(0x1000 | 0x0200) // controlKey | shiftKey
        }
    }
    
    var shortModifierDescription: String {
        switch self {
        case .controlOption: return "⌃⌥"
        case .controlCommand: return "⌃⌘"
        case .optionCommand: return "⌥⌘"
        case .controlShift: return "⌃⇧"
        }
    }
}

enum HotkeyTriggerKey: String, CaseIterable, Identifiable, Codable {
    case space = "Space"
    case returnKey = "Return"
    case tab = "Tab"
    case escape = "Escape"
    case d = "D"
    case r = "R"
    case grave = "Grave Accent (`)"

    var id: String { self.rawValue }

    var keyCode: UInt32 {
        switch self {
        case .space: return 49
        case .returnKey: return 36
        case .tab: return 48
        case .escape: return 53
        case .d: return 2
        case .r: return 15
        case .grave: return 50
        }
    }

    var shortDescription: String {
        switch self {
        case .space: return "Space"
        case .returnKey: return "↩"
        case .tab: return "⇥"
        case .escape: return "⎋"
        case .d: return "D"
        case .r: return "R"
        case .grave: return "`"
        }
    }
}

enum HotkeyMode: String, CaseIterable, Identifiable, Codable {
    case hold = "Hold to Speak"
    case toggle = "Press to Start/Stop"

    var id: String { self.rawValue }
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
    @Published var textTransformation: TextTransformation {
        didSet { defaults.set(textTransformation.rawValue, forKey: Keys.textTransformation) }
    }
    @Published var customPrefix: String {
        didSet { defaults.set(customPrefix, forKey: Keys.customPrefix) }
    }
    @Published var customSuffix: String {
        didSet { defaults.set(customSuffix, forKey: Keys.customSuffix) }
    }
    @Published var hotkeyModifiers: HotkeyModifiersCombo {
        didSet {
            defaults.set(hotkeyModifiers.rawValue, forKey: Keys.hotkeyModifiers)
            hotkeyChanged.send()
        }
    }
    @Published var hotkeyTriggerKey: HotkeyTriggerKey {
        didSet {
            defaults.set(hotkeyTriggerKey.rawValue, forKey: Keys.hotkeyTriggerKey)
            hotkeyChanged.send()
        }
    }
    @Published var hotkeyMode: HotkeyMode {
        didSet {
            defaults.set(hotkeyMode.rawValue, forKey: Keys.hotkeyMode)
            hotkeyChanged.send()
        }
    }
    @Published var showFloatingHUD: Bool {
        didSet { defaults.set(showFloatingHUD, forKey: Keys.showFloatingHUD) }
    }
    @Published var useCustomShortcut: Bool {
        didSet {
            defaults.set(useCustomShortcut, forKey: Keys.useCustomShortcut)
            hotkeyChanged.send()
        }
    }
    @Published var customModifiers: UInt32 {
        didSet {
            defaults.set(customModifiers, forKey: Keys.customModifiers)
            hotkeyChanged.send()
        }
    }
    @Published var customKeyCode: UInt32 {
        didSet {
            defaults.set(customKeyCode, forKey: Keys.customKeyCode)
            hotkeyChanged.send()
        }
    }
    @Published var customShortcutText: String {
        didSet {
            defaults.set(customShortcutText, forKey: Keys.customShortcutText)
            hotkeyChanged.send()
        }
    }
    @Published var isRecordingShortcut: Bool = false
    @Published var audioLevel: Float = 0.0

    let hotkeyChanged = PassthroughSubject<Void, Never>()

    var hotkeyDescription: String {
        if useCustomShortcut {
            return customShortcutText
        } else {
            return hotkeyModifiers.shortModifierDescription + hotkeyTriggerKey.shortDescription
        }
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
        static let textTransformation = "Whisp.textTransformation"
        static let customPrefix = "Whisp.customPrefix"
        static let customSuffix = "Whisp.customSuffix"
        static let hotkeyModifiers = "Whisp.hotkeyModifiers"
        static let hotkeyTriggerKey = "Whisp.hotkeyTriggerKey"
        static let hotkeyMode = "Whisp.hotkeyMode"
        static let showFloatingHUD = "Whisp.showFloatingHUD"
        static let useCustomShortcut = "Whisp.useCustomShortcut"
        static let customModifiers = "Whisp.customModifiers"
        static let customKeyCode = "Whisp.customKeyCode"
        static let customShortcutText = "Whisp.customShortcutText"
    }

    private let defaults = UserDefaults.standard
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingStartedAt: Date?
    private var finishWorkItem: DispatchWorkItem?
    var isHotkeyCurrentlyPressed = false
    private var pendingPasteText: String?

    init() {
        autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        copyToClipboard = defaults.object(forKey: Keys.copyToClipboard) as? Bool ?? true
        smartCleanup = defaults.object(forKey: Keys.smartCleanup) as? Bool ?? true
        selectedLocaleIdentifier = defaults.string(forKey: Keys.locale) ?? "en-US"
        history = Self.loadHistory(from: defaults)

        let transformationRaw = defaults.string(forKey: Keys.textTransformation) ?? ""
        textTransformation = TextTransformation(rawValue: transformationRaw) ?? .standard
        customPrefix = defaults.string(forKey: Keys.customPrefix) ?? ""
        customSuffix = defaults.string(forKey: Keys.customSuffix) ?? ""
        
        let modifierRaw = defaults.string(forKey: Keys.hotkeyModifiers) ?? ""
        hotkeyModifiers = HotkeyModifiersCombo(rawValue: modifierRaw) ?? .controlOption
        
        let keyRaw = defaults.string(forKey: Keys.hotkeyTriggerKey) ?? ""
        hotkeyTriggerKey = HotkeyTriggerKey(rawValue: keyRaw) ?? .space
        
        let modeRaw = defaults.string(forKey: Keys.hotkeyMode) ?? ""
        hotkeyMode = HotkeyMode(rawValue: modeRaw) ?? .hold
        
        showFloatingHUD = defaults.object(forKey: Keys.showFloatingHUD) as? Bool ?? true
        useCustomShortcut = defaults.object(forKey: Keys.useCustomShortcut) as? Bool ?? false
        customModifiers = defaults.object(forKey: Keys.customModifiers) as? UInt32 ?? UInt32(0x1000 | 0x0800) // Control + Option
        customKeyCode = defaults.object(forKey: Keys.customKeyCode) as? UInt32 ?? 49 // Space
        customShortcutText = defaults.string(forKey: Keys.customShortcutText) ?? "⌃⌥Space"
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
        pendingPasteText = nil

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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            
            guard let channelData = buffer.floatChannelData else { return }
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            
            var sum: Float = 0.0
            var count = 0
            for channel in 0..<channelCount {
                let data = channelData[channel]
                for frame in 0..<frameLength {
                    let val = data[frame]
                    sum += val * val
                    count += 1
                }
            }
            
            let rms = count > 0 ? sqrt(sum / Float(count)) : 0.0
            let db = rms > 0 ? 20 * log10(rms) : -160.0
            let minDb: Float = -45.0
            let maxDb: Float = -5.0
            let level = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))
            
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
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

        // Snapshot the frontmost app BEFORE we flip isRecording (which may show HUD/popover)
        PasteService.saveFrontmostApp()

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    func cancelRecording() {
        finishWorkItem?.cancel()
        pendingPasteText = nil
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
        audioLevel = 0.0
    }

    func hotkeyReleased() {
        isHotkeyCurrentlyPressed = false
        if let pending = pendingPasteText {
            pendingPasteText = nil
            if autoPaste {
                let delay = 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    PasteService.pasteToFrontApp()
                }
            }
        }
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
        audioLevel = 0.0

        let cleaned = clean(rawText)
        liveTranscript = cleaned
        guard !cleaned.isEmpty else { return }

        lastTranscript = cleaned
        addHistory(cleaned)

        if copyToClipboard || autoPaste {
            ClipboardService.copy(cleaned)
        }

        if autoPaste {
            if hotkeyMode == .hold && isHotkeyCurrentlyPressed {
                pendingPasteText = cleaned
            } else {
                let delay = 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    PasteService.pasteToFrontApp()
                }
            }
        }
    }

    private func clean(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return cleaned }

        if smartCleanup {
            cleaned = removeFillerWords(cleaned)
            guard !cleaned.isEmpty else { return "" }
        }

        switch textTransformation {
        case .raw:
            break
        case .standard:
            let first = cleaned.prefix(1).uppercased()
            cleaned = first + cleaned.dropFirst()
            if let last = cleaned.last, !".!?".contains(last) {
                cleaned += "."
            }
        case .bulletList:
            // Split by sentence delimiters but keep them or handle splitting cleanly
            let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            cleaned = sentences.map { "- \($0)" }.joined(separator: "\n")
        case .titleCase:
            cleaned = cleaned.capitalized
        case .upperCase:
            cleaned = cleaned.uppercased()
        case .snakeCase:
            cleaned = cleaned.lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }

        if !customPrefix.isEmpty {
            cleaned = customPrefix + cleaned
        }

        if !customSuffix.isEmpty {
            cleaned = cleaned + customSuffix
        }

        return cleaned
    }

    private func removeFillerWords(_ text: String) -> String {
        let pattern = "\\b(um|uh|ah|er|eh|hm|umm|uhh|ahh)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        var cleaned = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        
        // Clean up punctuation and spaces
        cleaned = cleaned.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: ",\\s*([\\.\\?\\!])", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix(",") {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasSuffix(",") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let trimmedPunctuation = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,?! "))
        if trimmedPunctuation.isEmpty {
            return ""
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

