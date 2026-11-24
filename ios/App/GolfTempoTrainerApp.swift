import SwiftUI
import SwiftData

@main
struct GolfTempoTrainerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: TrainingSession.self)
    }
}
