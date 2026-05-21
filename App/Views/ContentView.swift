import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DictationStore
    let updater: UpdaterController

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
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                if store.isRecording {
                    WaveVisualizerView()
                } else {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Whisp")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                Text(store.isRecording ? "Listening... press \(store.hotkeyModifiers.shortDescription) to stop" : "\(store.hotkeyModifiers.shortDescription) to dictate")
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
                            WaveVisualizerView()
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

            Picker("Shortcut Modifiers", selection: $store.hotkeyModifiers) {
                ForEach(HotkeyModifiersCombo.allCases) { combo in
                    Text(combo.rawValue).tag(combo)
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
        return store.lastTranscript.isEmpty ? "Press Dictate or \(store.hotkeyModifiers.shortDescription)." : store.lastTranscript
    }
}

struct WaveVisualizerView: View {
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
        return 8 + normalized * 18
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

