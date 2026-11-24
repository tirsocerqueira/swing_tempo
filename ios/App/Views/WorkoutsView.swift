import SwiftUI

public struct WorkoutsView: View {
    @Bindable private var viewModel: TempoTrainerViewModel
    private let onStartWorkout: () -> Void

    public init(
        viewModel: TempoTrainerViewModel,
        onStartWorkout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onStartWorkout = onStartWorkout
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Entrenamientos")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                ForEach(GuidedWorkout.presets) { workout in
                    Button {
                        viewModel.select(workout)
                        onStartWorkout()
                    } label: {
                        workoutCard(
                            title: workout.title,
                            detail: workout.description,
                            repetitions: workout.repetitions
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Selecciona esta sesión y abre el entrenador")
                }

                freePracticeCard
            }
            .padding(22)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.045))
        .preferredColorScheme(.dark)
    }

    private var freePracticeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Modo libre")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Ajusta tempo, duración y recuperación.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(golfGreen)
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Relación")
                    Spacer()
                    Text(String(format: "%.1f:1", viewModel.customRatio))
                        .monospacedDigit()
                        .foregroundStyle(golfGreen)
                }
                Slider(value: $viewModel.customRatio, in: 2...4, step: 0.5)
                    .tint(golfGreen)

                Stepper(
                    "Repeticiones: \(viewModel.repetitions)",
                    value: $viewModel.repetitions,
                    in: 1...100
                )
                Stepper(
                    "Descanso: \(viewModel.restBetweenSwingsMilliseconds / 1_000) s",
                    value: $viewModel.restBetweenSwingsMilliseconds,
                    in: 0...30_000,
                    step: 1_000
                )
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white)

            Button {
                viewModel.selectFreePractice()
                onStartWorkout()
            } label: {
                Label("Configurar entrenamiento", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.035, green: 0.055, blue: 0.045))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(golfGreen, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private func workoutCard(
        title: String,
        detail: String,
        repetitions: Int
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.golf")
                .font(.title2)
                .foregroundStyle(golfGreen)
                .frame(width: 48, height: 48)
                .background(golfGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.leading)
                Text("\(repetitions) swings")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(golfGreen)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var golfGreen: Color {
        Color(red: 0.37, green: 0.91, blue: 0.48)
    }
}
