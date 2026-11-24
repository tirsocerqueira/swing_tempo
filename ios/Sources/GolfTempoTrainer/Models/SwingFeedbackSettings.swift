import Foundation

public struct SwingFeedbackSettings: Equatable, Sendable {
    public let soundEnabled: Bool
    public let vibrationEnabled: Bool
    public let volume: Float
    public static let standard = SwingFeedbackSettings(
        defaultSoundEnabled: true,
        vibrationEnabled: false,
        volume: 0.6
    )

    public init(
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = false,
        volume: Float = 0.6
    ) throws {
        guard volume.isFinite, (0...1).contains(volume) else {
            throw SwingFeedbackSettingsError.invalidVolume
        }

        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.volume = volume
    }

    private init(
        defaultSoundEnabled soundEnabled: Bool,
        vibrationEnabled: Bool,
        volume: Float
    ) {
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.volume = volume
    }
}

public enum SwingFeedbackSettingsError: LocalizedError, Equatable {
    case invalidVolume

    public var errorDescription: String? {
        "El volumen debe estar entre 0 y 100 %."
    }
}
