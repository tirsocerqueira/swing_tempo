import Foundation
import SwiftData

@Model
public final class TrainingSession {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var tempoRatio: Double
    public var backswingDurationMilliseconds: Int
    public var downswingDurationMilliseconds: Int
    public var swingCount: Int
    public var durationSeconds: Double
    public var workoutTypeRawValue: String

    public init(
        id: UUID = UUID(),
        date: Date,
        tempoRatio: Double,
        backswingDurationMilliseconds: Int,
        downswingDurationMilliseconds: Int,
        swingCount: Int,
        durationSeconds: Double,
        workoutType: WorkoutType
    ) {
        self.id = id
        self.date = date
        self.tempoRatio = tempoRatio
        self.backswingDurationMilliseconds = backswingDurationMilliseconds
        self.downswingDurationMilliseconds = downswingDurationMilliseconds
        self.swingCount = swingCount
        self.durationSeconds = durationSeconds
        self.workoutTypeRawValue = workoutType.rawValue
    }

    public var workoutType: WorkoutType? {
        WorkoutType(rawValue: workoutTypeRawValue)
    }
}
