import Foundation

public struct SwingWorkoutConfiguration: Equatable, Sendable {
    public let timing: SwingTiming
    public let repetitions: Int
    public let restBetweenSwingsMilliseconds: Int
    public let workoutType: WorkoutType

    public init(
        timing: SwingTiming,
        repetitions: Int,
        restBetweenSwingsMilliseconds: Int = 0,
        workoutType: WorkoutType = .freePractice
    ) throws {
        guard repetitions > 0 else {
            throw SwingWorkoutConfigurationError.invalidRepetitions
        }
        guard restBetweenSwingsMilliseconds >= 0 else {
            throw SwingWorkoutConfigurationError.invalidRestDuration
        }

        self.timing = timing
        self.repetitions = repetitions
        self.restBetweenSwingsMilliseconds = restBetweenSwingsMilliseconds
        self.workoutType = workoutType
    }
}

public enum SwingWorkoutConfigurationError: LocalizedError, Equatable {
    case invalidRepetitions
    case invalidRestDuration

    public var errorDescription: String? {
        switch self {
        case .invalidRepetitions:
            "El entrenamiento debe tener al menos una repetición."
        case .invalidRestDuration:
            "El descanso no puede ser negativo."
        }
    }
}
