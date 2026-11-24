import Foundation

public enum WorkoutType: String, CaseIterable, Codable, Identifiable, Sendable {
    case warmup
    case tempoControl
    case consistency
    case advanced
    case freePractice

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .warmup: "Calentamiento"
        case .tempoControl: "Control del tempo"
        case .consistency: "Consistencia"
        case .advanced: "Entrenamiento avanzado"
        case .freePractice: "Modo libre"
        }
    }
}

public struct GuidedWorkout: Equatable, Identifiable, Sendable {
    public let type: WorkoutType
    public let description: String
    public let repetitions: Int

    public var id: WorkoutType { type }
    public var title: String { type.title }

    public init(type: WorkoutType, description: String, repetitions: Int) {
        self.type = type
        self.description = description
        self.repetitions = repetitions
    }

    public static let presets: [GuidedWorkout] = [
        GuidedWorkout(
            type: .warmup,
            description: "Prepara el cuerpo y encuentra un ritmo cómodo.",
            repetitions: 10
        ),
        GuidedWorkout(
            type: .tempoControl,
            description: "Practica una secuencia constante en cada swing.",
            repetitions: 20
        ),
        GuidedWorkout(
            type: .consistency,
            description: "Mantén el mismo tempo a lo largo de la sesión.",
            repetitions: 30
        ),
        GuidedWorkout(
            type: .advanced,
            description: "Sesión larga para afianzar el ritmo bajo fatiga.",
            repetitions: 50
        )
    ]
}
