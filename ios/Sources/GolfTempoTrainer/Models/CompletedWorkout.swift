import Foundation

public struct CompletedWorkout: Equatable, Sendable {
    public let date: Date
    public let timing: SwingTiming
    public let swingCount: Int
    public let durationSeconds: Double
    public let workoutType: WorkoutType

    public init(
        date: Date,
        timing: SwingTiming,
        swingCount: Int,
        durationSeconds: Double,
        workoutType: WorkoutType
    ) {
        self.date = date
        self.timing = timing
        self.swingCount = swingCount
        self.durationSeconds = durationSeconds
        self.workoutType = workoutType
    }
}
