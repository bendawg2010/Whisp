import SwiftUI
import Carbon

struct ContentView: View {
    @ObservedObject var store: DictationStore
    let updater: UpdaterController
    @State private var shortcutMonitor: Any? = nil

    private var statusColor: Color {
        if store.isRecording { return .red }
        if store.isFinishing { return .orange }
        if store.errorMessage != nil { return .yellow }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            transcriptBox
            settings
            history
            footer
        }
        .padding(20)
        .frame(width: 430)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.02, blue: 0.08), Color(red: 0.07, green: 0.06, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                if store.isRecording {
                    WaveVisualizerView(store: store)
                } else {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Whisp")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                Text(store.isRecording ? (store.hotkeyMode == .hold ? "Listening... release \(store.hotkeyDescription) to stop" : "Listening... press \(store.hotkeyDescription) to stop") : (store.hotkeyMode == .hold ? "Hold \(store.hotkeyDescription) to dictate" : "Press \(store.hotkeyDescription) to dictate"))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleRecording()
            } label: {
                Label(store.isRecording ? "Stop" : "Dictate", systemImage: store.isRecording ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isRecording: store.isRecording))

            Button {
                store.pasteLastTranscript()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(IconButtonStyle())
            .help("Paste last transcript")
            .disabled(store.lastTranscript.isEmpty)

            Button {
                store.copyLastTranscript()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(IconButtonStyle())
            .help("Copy last transcript")
            .disabled(store.lastTranscript.isEmpty)
        }
    }

    private var transcriptBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.isRecording ? "Live transcript" : "Last transcript")
                    .font(.headline)
                Spacer()
                if store.isFinishing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.orange)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if store.isRecording && store.liveTranscript.isEmpty {
                        HStack(spacing: 8) {
                            WaveVisualizerView(store: store)
                            Text("Start talking...")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    } else {
                        Text(transcriptText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(transcriptText.isEmpty ? .white.opacity(0.35) : .white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
            }
            .frame(height: 132)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } else {
                Text(store.permissionSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Language", selection: $store.selectedLocaleIdentifier) {
                ForEach(DictationStore.locales) { locale in
                    Text(locale.name).tag(locale.id)
                }
            }
            .pickerStyle(.menu)

            Picker("Text Style", selection: $store.textTransformation) {
                ForEach(TextTransformation.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.menu)

            if store.useCustomShortcut {
                HStack(spacing: 8) {
                    Text("Shortcut:")
                        .font(.body)
                    Spacer()
                    Text(store.customShortcutText)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                    
                    Button("Reset") {
                        store.useCustomShortcut = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Shortcut Modifiers", selection: $store.hotkeyModifiers) {
                        ForEach(HotkeyModifiersCombo.allCases) { combo in
                            Text(combo.rawValue).tag(combo)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Shortcut Key", selection: $store.hotkeyTriggerKey) {
                        ForEach(HotkeyTriggerKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Button(action: {
                if store.isRecordingShortcut {
                    stopRecordingShortcut()
                } else {
                    startRecordingShortcut()
                }
            }) {
                HStack {
                    Image(systemName: store.isRecordingShortcut ? "record.circle" : "keyboard")
                    Text(store.isRecordingShortcut ? "Press key combination... (Esc to cancel)" : "Record Custom Shortcut")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(store.isRecordingShortcut ? .red : .accentColor)

            Picker("Recording Mode", selection: $store.hotkeyMode) {
                ForEach(HotkeyMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Prefix:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 44, alignment: .leading)
                    TextField("Prepended text", text: $store.customPrefix)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
                HStack(spacing: 8) {
                    Text("Suffix:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 44, alignment: .leading)
                    TextField("Appended text", text: $store.customSuffix)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
            }
            .padding(.vertical, 4)

            Toggle("Auto-paste after dictation", isOn: $store.autoPaste)
            Toggle("Copy transcript to clipboard", isOn: $store.copyToClipboard)
            Toggle("Smart Formatting (remove 'um', 'uh', etc.)", isOn: $store.smartCleanup)
            Toggle("Show floating HUD overlay", isOn: $store.showFloatingHUD)
            Toggle("Launch at login", isOn: $store.launchAtLogin)
        }
        .toggleStyle(.switch)
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    store.clearHistory()
                }
                .disabled(store.history.isEmpty)
            }

            if store.history.isEmpty {
                Text("Your finished dictations will appear here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.history.prefix(4)) { item in
                            Button {
                                store.copy(item)
                            } label: {
                                Text(item.text)
                                    .lineLimit(2)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.84))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help("Copy this transcript")
                        }
                    }
                }
                .frame(maxHeight: 142)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                updater.checkForUpdates(nil)
            } label: {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                PasteService.openAccessibilitySettings()
            } label: {
                Label("Accessibility", systemImage: "accessibility")
            }

            Spacer()

            Link("MIT", destination: URL(string: "https://github.com/bendawg2010/Whisp")!)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.65))
    }

    private var transcriptText: String {
        if store.isRecording || store.isFinishing {
            return store.liveTranscript.isEmpty ? "Start talking..." : store.liveTranscript
        }
        return store.lastTranscript.isEmpty ? (store.hotkeyMode == .hold ? "Hold \(store.hotkeyDescription) to dictate." : "Press \(store.hotkeyDescription) to dictate.") : store.lastTranscript
    }

    private func startRecordingShortcut() {
        store.isRecordingShortcut = true
        stopRecordingShortcut()
        
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Escape to cancel
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                stopRecordingShortcut()
                return nil
            }
            
            let flags = event.modifierFlags
            var carbonMods: UInt32 = 0
            var descParts: [String] = []
            
            if flags.contains(.control) {
                carbonMods |= UInt32(0x1000) // controlKey
                descParts.append("⌃")
            }
            if flags.contains(.option) {
                carbonMods |= UInt32(0x0800) // optionKey
                descParts.append("⌥")
            }
            if flags.contains(.command) {
                carbonMods |= UInt32(0x0100) // cmdKey
                descParts.append("⌘")
            }
            if flags.contains(.shift) {
                carbonMods |= UInt32(0x0200) // shiftKey
                descParts.append("⇧")
            }
            
            if event.type == .keyDown {
                let keyCode = UInt32(event.keyCode)
                let keyStr = stringFromKeyCode(keyCode)
                descParts.append(keyStr)
                
                store.customModifiers = carbonMods
                store.customKeyCode = keyCode
                store.customShortcutText = descParts.joined()
                store.useCustomShortcut = true
                
                stopRecordingShortcut()
                return nil // consume the event
            }
            
            return event
        }
    }
    
    private func stopRecordingShortcut() {
        store.isRecordingShortcut = false
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
    }
    
    private func stringFromKeyCode(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        // Letters
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        // Numbers
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        // Special keys
        case 50: return "`"
        default:
            if let string = stringFromKeycodeTranslation(keyCode) {
                return string.uppercased()
            }
            return "Key\(keyCode)"
        }
    }
    
    private func stringFromKeycodeTranslation(_ keyCode: UInt32) -> String? {
        let maxStringLength = 16
        var stringLength = 0
        var unicodeString = [UniChar](repeating: 0, count: maxStringLength)
        
        guard let keyboardLayout = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        
        let layoutData = TISGetInputSourceProperty(keyboardLayout, kTISPropertyUnicodeKeyLayoutData)
        guard let layoutDataRef = layoutData else {
            return nil
        }
        
        let layoutDataPtr = unsafeBitCast(layoutDataRef, to: CFData.self)
        let rawLayoutData = CFDataGetBytePtr(layoutDataPtr)
        let keyboardLayoutPtr = unsafeBitCast(rawLayoutData, to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeys: UInt32 = 0
        let result = UCKeyTranslate(
            keyboardLayoutPtr,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            maxStringLength,
            &stringLength,
            &unicodeString
        )
        
        if result == noErr && stringLength > 0 {
            return String(utf16CodeUnits: unicodeString, count: stringLength)
        }
        return nil
    }
}

struct WaveVisualizerView: View {
    @ObservedObject var store: DictationStore
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .yellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: getHeight(for: index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func getHeight(for index: Int) -> CGFloat {
        let base = sin(phase + CGFloat(index) * 0.8)
        let normalized = (base + 1.0) / 2.0 // 0 to 1
        
        let level = CGFloat(store.audioLevel)
        let factor = 6 + level * 20 + normalized * (4 + level * 8)
        return min(28, max(4, factor))
    }
}

struct SettingsView: View {
    @ObservedObject var store: DictationStore
    let updater: UpdaterController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Whisp Settings")
                .font(.largeTitle.bold())
            ContentView(store: store, updater: updater)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack {
                Button("Check for Updates") {
                    updater.checkForUpdates(nil)
                }
                Button("Force Update Now") {
                    updater.forceUpdateNow(nil)
                }
                Spacer()
            }
        }
        .padding(22)
        .frame(width: 500)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: isRecording
                    ? [Color.red, Color.orange]
                    : [Color(red: 1.0, green: 0.42, blue: 0.42), Color(red: 0.18, green: 0.90, blue: 0.63)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

