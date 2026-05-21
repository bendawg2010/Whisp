import SwiftUI

struct FloatingHUDView: View {
    @ObservedObject var store: DictationStore

    var body: some View {
        HStack(spacing: 16) {
            // Pulsing recording dot
            // Responsive voice level visualizer bar
            MiniWaveVisualizerView(store: store)
                .frame(width: 24, height: 22)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Whisp is listening...")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(store.liveTranscript.isEmpty ? "Start speaking..." : store.liveTranscript)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .multilineTextAlignment(.leading)
                    .frame(minWidth: 200, maxWidth: 450, alignment: .leading)
            }
            
            // Modifier key tip
            Text(store.hotkeyDescription)
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.03, blue: 0.09).opacity(0.88))
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 8)
    }
}

struct MiniWaveVisualizerView: View {
    @ObservedObject var store: DictationStore
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .yellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: getHeight(for: index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func getHeight(for index: Int) -> CGFloat {
        let base = sin(phase + CGFloat(index) * 1.0)
        let normalized = (base + 1.0) / 2.0
        let level = CGFloat(store.audioLevel)
        let factor = 4 + level * 16 + normalized * (3 + level * 6)
        return min(22, max(4, factor))
    }
}

