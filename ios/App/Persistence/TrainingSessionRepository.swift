import Foundation
import SwiftData

@MainActor
public enum TrainingSessionRepository {
    public static func save(
        _ workout: CompletedWorkout,
        in context: ModelContext
    ) throws {
        let session = TrainingSession(
            date: workout.date,
            tempoRatio: workout.timing.backswingToDownswingRatio,
            backswingDurationMilliseconds: workout.timing.backswingDurationMilliseconds,
            downswingDurationMilliseconds: workout.timing.downswingDurationMilliseconds,
            swingCount: workout.swingCount,
            durationSeconds: workout.durationSeconds,
            workoutType: workout.workoutType
        )
        context.insert(session)
        try context.save()
    }
}
