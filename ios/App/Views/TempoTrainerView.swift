import UIKit
import SwiftUI

public struct TempoTrainerView: View {
    @State private var viewModel = TempoTrainerViewModel()

    public init(viewModel: TempoTrainerViewModel = TempoTrainerViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 6) {
                    Text("GOLF TEMPO")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("TRAINER")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(golfGreen)
                }
                .padding(.top, 18)

                SwingPhaseIndicator(
                    phase: viewModel.phase,
                    remainingMilliseconds: viewModel.remainingMilliseconds,
                    phaseDurationMilliseconds: viewModel.phaseDurationMilliseconds
                )
                .padding(.vertical, 4)

                HStack(spacing: 0) {
                    metric(
                        title: "TEMPO",
                        value: viewModel.selectedPreset.label
                    )
                    Spacer()
                    metric(
                        title: "SWINGS",
                        value: "\(viewModel.completedSwings) / \(viewModel.repetitions)"
                    )
                }
                .padding(.horizontal, 12)

                VStack(spacing: 18) {
                    if viewModel.usesCustomRatio {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Relación backswing:downswing")
                                Spacer()
                                Text(String(format: "%.1f:1", viewModel.customRatio))
                                    .monospacedDigit()
                                    .foregroundStyle(golfGreen)
                            }
                            Slider(
                                value: $viewModel.customRatio,
                                in: 2...4,
                                step: 0.5
                            )
                            .tint(golfGreen)
                            .disabled(!viewModel.isIdle)
                        }
                    } else {
                        Picker("Tempo", selection: $viewModel.selectedPreset) {
                            ForEach(SwingTempoPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!viewModel.isIdle)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duración total")
                            Spacer()
                            Text("\(Int(viewModel.totalDurationMilliseconds)) ms")
                                .monospacedDigit()
                                .foregroundStyle(golfGreen)
                        }
                        Slider(
                            value: $viewModel.totalDurationMilliseconds,
                            in: 750...3_000,
                            step: 50
                        )
                        .tint(golfGreen)
                        .disabled(!viewModel.isIdle)
                    }

                    Stepper(
                        "Repeticiones: \(viewModel.repetitions)",
                        value: $viewModel.repetitions,
                        in: 1...100
                    )
                    .disabled(!viewModel.isIdle)

                    Stepper(
                        "Descanso: \(viewModel.restBetweenSwingsMilliseconds / 1_000) s",
                        value: $viewModel.restBetweenSwingsMilliseconds,
                        in: 0...30_000,
                        step: 1_000
                    )
                    .disabled(!viewModel.isIdle)
                }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .padding(18)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.performPrimaryAction() }
                    } label: {
                        Label(
                            viewModel.primaryActionTitle,
                            systemImage: viewModel.isRunning
                                ? "pause.fill"
                                : viewModel.isPaused ? "play.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryTrainingButtonStyle())

                    if !viewModel.isIdle {
                        Button {
                            Task { await viewModel.stop() }
                        } label: {
                            Image(systemName: "stop.fill")
                                .frame(width: 58, height: 58)
                        }
                        .buttonStyle(StopTrainingButtonStyle())
                        .accessibilityLabel("Detener entrenamiento")
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)
                        .onTapGesture { viewModel.clearError() }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.045))
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.engineState) { _, state in
            UIApplication.shared.isIdleTimerDisabled = state == .running
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = viewModel.isRunning
        }
    }

    private var golfGreen: Color {
        Color(red: 0.37, green: 0.91, blue: 0.48)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct PrimaryTrainingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color(red: 0.035, green: 0.055, blue: 0.045))
            .frame(height: 58)
            .background(
                Color(red: 0.37, green: 0.91, blue: 0.48)
                    .opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}

private struct StopTrainingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.16 : 0.08),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
