import Foundation

public enum SwingTempoPreset: CaseIterable, Hashable, Identifiable, Sendable {
    case twoToOne
    case twoPointFiveToOne
    case threeToOne
    case threePointFiveToOne
    case fourToOne

    public var id: String { label }

    public var label: String {
        switch self {
        case .twoToOne: "2:1"
        case .twoPointFiveToOne: "2.5:1"
        case .threeToOne: "3:1"
        case .threePointFiveToOne: "3.5:1"
        case .fourToOne: "4:1"
        }
    }

    public var backswingToDownswingRatio: Double {
        switch self {
        case .twoToOne: 2
        case .twoPointFiveToOne: 2.5
        case .threeToOne: 3
        case .threePointFiveToOne: 3.5
        case .fourToOne: 4
        }
    }

    public func timing(totalDurationMilliseconds: Int) throws -> SwingTiming {
        try SwingTiming(
            totalDurationMilliseconds: totalDurationMilliseconds,
            backswingToDownswingRatio: backswingToDownswingRatio
        )
    }
}
