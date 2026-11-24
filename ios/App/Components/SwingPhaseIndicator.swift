import SwiftUI

public struct SwingPhaseIndicator: View {
    public let phase: TrainerDisplayPhase
    public let remainingMilliseconds: Int
    public let phaseDurationMilliseconds: Int

    public init(
        phase: TrainerDisplayPhase,
        remainingMilliseconds: Int,
        phaseDurationMilliseconds: Int
    ) {
        self.phase = phase
        self.remainingMilliseconds = remainingMilliseconds
        self.phaseDurationMilliseconds = phaseDurationMilliseconds
    }

    private var progress: Double {
        guard phase != .ready, phaseDurationMilliseconds > 0 else {
            return 0.72
        }
        return min(
            max(
                1 - Double(remainingMilliseconds)
                    / Double(phaseDurationMilliseconds),
                0.02
            ),
            1
        )
    }

    private var title: String {
        switch phase {
        case .ready: "READY"
        case .backswing: "BACKSWING"
        case .transition: "TRANSITION"
        case .downswing: "DOWNSWING / IMPACT"
        case .rest: "REST"
        }
    }

    private var accent: Color {
        switch phase {
        case .ready: Color.white.opacity(0.35)
        case .backswing: Color(red: 0.37, green: 0.91, blue: 0.48)
        case .transition: Color(red: 0.96, green: 0.76, blue: 0.31)
        case .downswing: Color(red: 0.74, green: 0.96, blue: 0.35)
        case .rest: Color(red: 0.36, green: 0.67, blue: 0.93)
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Text(phase == .ready ? "—" : "\(remainingMilliseconds) ms")
                    .font(.system(.title2, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 230, height: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fase: \(title)")
        .accessibilityValue(
            phase == .ready ? "Preparado" : "\(remainingMilliseconds) milisegundos"
        )
    }
}
