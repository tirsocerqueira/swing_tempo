import Foundation

/// Divides a swing's total duration into integer millisecond intervals.
/// Rounding is applied to the backswing; the downswing receives the remainder.
public struct SwingTiming: Equatable, Sendable {
    public let totalDurationMilliseconds: Int
    public let backswingDurationMilliseconds: Int
    public let downswingDurationMilliseconds: Int
    public let backswingToDownswingRatio: Double

    public init(
        totalDurationMilliseconds: Int,
        backswingToDownswingRatio: Double
    ) throws {
        guard totalDurationMilliseconds > 0 else {
            throw SwingTimingError.invalidTotalDuration
        }
        guard backswingToDownswingRatio.isFinite,
              backswingToDownswingRatio > 0 else {
            throw SwingTimingError.invalidRatio
        }

        let backswing = Int(
            (Double(totalDurationMilliseconds) * backswingToDownswingRatio
                / (backswingToDownswingRatio + 1))
                .rounded()
        )
        guard backswing > 0, backswing < totalDurationMilliseconds else {
            throw SwingTimingError.invalidDurationResolution
        }

        self.totalDurationMilliseconds = totalDurationMilliseconds
        self.backswingDurationMilliseconds = backswing
        self.downswingDurationMilliseconds = totalDurationMilliseconds - backswing
        self.backswingToDownswingRatio = backswingToDownswingRatio
    }
}

public enum SwingTimingError: LocalizedError, Equatable {
    case invalidTotalDuration
    case invalidRatio
    case invalidDurationResolution

    public var errorDescription: String? {
        switch self {
        case .invalidTotalDuration:
            "La duración total debe ser mayor que cero."
        case .invalidRatio:
            "La relación de tempo debe ser un número positivo."
        case .invalidDurationResolution:
            "La duración no permite representar ambas fases en milisegundos."
        }
    }
}
