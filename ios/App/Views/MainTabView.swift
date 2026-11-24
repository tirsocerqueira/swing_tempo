import SwiftData
import SwiftUI

public struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.date, order: .reverse)
    private var sessions: [TrainingSession]
    @State private var trainer = TempoTrainerViewModel()
    @State private var selectedTab = AppTab.home
    @State private var persistenceError: String?
    @AppStorage("trainer.defaultDurationMilliseconds")
    private var defaultDurationMilliseconds = 1_250

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                sessions: sessions,
                selectedTempo: formatRatio(trainer.currentRatio),
                onStartWorkout: {
                    trainer.select(GuidedWorkout.presets[0])
                    selectedTab = .trainer
                }
            )
            .tabItem { Label("Inicio", systemImage: "house.fill") }
            .tag(AppTab.home)

            TempoTrainerView(viewModel: trainer)
                .tabItem { Label("Entrenar", systemImage: "metronome.fill") }
                .tag(AppTab.trainer)

            WorkoutsView(
                viewModel: trainer,
                onStartWorkout: { selectedTab = .trainer }
            )
            .tabItem { Label("Sesiones", systemImage: "figure.golf") }
            .tag(AppTab.workouts)

            StatisticsView(sessions: sessions)
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.statistics)

            NavigationStack {
                SettingsView(viewModel: trainer) { duration in
                    trainer.totalDurationMilliseconds = Double(duration)
                }
            }
            .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
            .tag(AppTab.settings)
        }
        .tint(Color(red: 0.37, green: 0.91, blue: 0.48))
        .preferredColorScheme(.dark)
        .onAppear {
            trainer.totalDurationMilliseconds = Double(defaultDurationMilliseconds)
            trainer.onWorkoutCompleted = { workout in
                do {
                    try TrainingSessionRepository.save(workout, in: modelContext)
                } catch {
                    persistenceError = error.localizedDescription
                }
            }
        }
        .alert(
            "No se pudo guardar la sesión",
            isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Error de persistencia desconocido.")
        }
    }
}

private enum AppTab: Hashable {
    case home
    case trainer
    case workouts
    case statistics
    case settings
}

private struct HomeView: View {
    let sessions: [TrainingSession]
    let selectedTempo: String
    let onStartWorkout: () -> Void

    private var totalSwings: Int {
        sessions.reduce(0) { $0 + $1.swingCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("GOLF TEMPO")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("TRAINER")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(golfGreen)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("ÚLTIMO ENTRENAMIENTO")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                    if let latest = sessions.first {
                        HStack(alignment: .firstTextBaseline) {
                            Text(latest.workoutType?.title ?? latest.workoutTypeRawValue)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Spacer()
                            Text(latest.date, style: .date)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Text(
                            "\(latest.swingCount) swings  ·  "
                                + "\(latest.tempoRatio.formatted(.number.precision(.fractionLength(1)))):1 tempo"
                        )
                        .font(.subheadline)
                        .foregroundStyle(golfGreen)
                    } else {
                        Text("Aún no hay sesiones guardadas.")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 12) {
                    summaryCard(title: "SWINGS", value: "\(totalSwings)")
                    summaryCard(title: "SESIONES", value: "\(sessions.count)")
                    summaryCard(title: "TEMPO", value: selectedTempo)
                }

                Button(action: onStartWorkout) {
                    Label("Empezar calentamiento", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.035, green: 0.055, blue: 0.045))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(golfGreen, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.045))
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private var golfGreen: Color {
        Color(red: 0.37, green: 0.91, blue: 0.48)
    }

}

private func formatRatio(_ ratio: Double) -> String {
    ratio.rounded() == ratio
        ? "\(Int(ratio)):1"
        : String(format: "%.1f:1", ratio)
}
