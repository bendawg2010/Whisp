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
                Image(systemName: store.isRecording ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Whisp")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                Text(store.isRecording ? "Listening... press Control Option Space to stop" : "Control Option Space to dictate")
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
                Text(transcriptText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(transcriptText.isEmpty ? .white.opacity(0.35) : .white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
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
        VStack(spacing: 10) {
            Picker("Language", selection: $store.selectedLocaleIdentifier) {
                ForEach(DictationStore.locales) { locale in
                    Text(locale.name).tag(locale.id)
                }
            }
            .pickerStyle(.menu)

            Toggle("Auto-paste after dictation", isOn: $store.autoPaste)
            Toggle("Copy transcript to clipboard", isOn: $store.copyToClipboard)
            Toggle("Smart cleanup", isOn: $store.smartCleanup)
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
        return store.lastTranscript.isEmpty ? "Press Dictate or Control Option Space." : store.lastTranscript
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

