import SwiftUI

struct SettingsView: View {
    @Bindable private var viewModel: TempoTrainerViewModel
    private let onDefaultDurationChange: (Int) -> Void

    @AppStorage("audio.soundEnabled") private var soundEnabled = true
    @AppStorage("audio.vibrationEnabled") private var vibrationEnabled = false
    @AppStorage("audio.volume") private var volume = 0.6
    @AppStorage("trainer.defaultDurationMilliseconds")
    private var defaultDurationMilliseconds = 1_250
    @State private var feedbackError: String?

    init(
        viewModel: TempoTrainerViewModel,
        onDefaultDurationChange: @escaping (Int) -> Void
    ) {
        self.viewModel = viewModel
        self.onDefaultDurationChange = onDefaultDurationChange
    }

    var body: some View {
        Form {
            Section("Señales") {
                Toggle(
                    "Sonido",
                    systemImage: "speaker.wave.2.fill",
                    isOn: $soundEnabled
                )
                Toggle(
                    "Vibración",
                    systemImage: "waveform",
                    isOn: $vibrationEnabled
                )
                if soundEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volumen")
                            Spacer()
                            Text("\(Int(volume * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(golfGreen)
                        }
                        Slider(value: $volume, in: 0...1)
                            .tint(golfGreen)
                    }
                }
                Text("Desactiva el sonido para entrenar en modo visual silencioso.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Entrenamiento") {
                Stepper(
                    value: $defaultDurationMilliseconds,
                    in: 750...3_000,
                    step: 50
                ) {
                    HStack {
                        Text("Duración inicial")
                        Spacer()
                        Text("\(defaultDurationMilliseconds) ms")
                            .monospacedDigit()
                            .foregroundStyle(golfGreen)
                    }
                }
            }

            Section {
                Text("Golf Tempo Trainer · iOS 18+")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.035, green: 0.055, blue: 0.045))
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .onAppear {
            onDefaultDurationChange(defaultDurationMilliseconds)
            applyFeedbackSettings()
        }
        .onChange(of: soundEnabled) { _, _ in applyFeedbackSettings() }
        .onChange(of: vibrationEnabled) { _, _ in applyFeedbackSettings() }
        .onChange(of: volume) { _, _ in applyFeedbackSettings() }
        .onChange(of: defaultDurationMilliseconds) { _, duration in
            onDefaultDurationChange(duration)
        }
        .alert(
            "No se pudo aplicar el ajuste",
            isPresented: Binding(
                get: { feedbackError != nil },
                set: { if !$0 { feedbackError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) { feedbackError = nil }
        } message: {
            Text(feedbackError ?? "Error de configuración desconocido.")
        }
    }

    private func applyFeedbackSettings() {
        do {
            let settings = try SwingFeedbackSettings(
                soundEnabled: soundEnabled,
                vibrationEnabled: vibrationEnabled,
                volume: Float(volume)
            )
            try viewModel.updateFeedbackSettings(settings)
            feedbackError = nil
        } catch {
            feedbackError = error.localizedDescription
        }
    }

    private var golfGreen: Color {
        Color(red: 0.37, green: 0.91, blue: 0.48)
    }
}
