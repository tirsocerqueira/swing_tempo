import AVFoundation
import Darwin
import Foundation
#if os(iOS)
import CoreHaptics
#endif

public enum SwingFeedbackError: LocalizedError {
    case audioResourceUnavailable
    case notPrepared
    case hapticsUnavailable

    public var errorDescription: String? {
        switch self {
        case .audioResourceUnavailable:
            "No se pudieron preparar los tonos de entrenamiento."
        case .notPrepared:
            "El sistema de señales no está preparado."
        case .hapticsUnavailable:
            "Este dispositivo no admite vibración háptica."
        }
    }
}

public final class SwingFeedbackService: @unchecked Sendable {
    private let lock = NSLock()
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var settings: SwingFeedbackSettings
    private var prepared = false
    private var audioConfigured = false
    private var audioInterrupted = false
    private var audioInterruptionObserver: NSObjectProtocol?
    private var buffers: [SwingTempoSignalKind: AVAudioPCMBuffer] = [:]
    public var errorHandler: (@Sendable (Error) -> Void)?
    #if os(iOS)
    private var hapticsEngine: CHHapticEngine?
    private var hapticsRunning = false
    private var hapticsRecoveryError: Error?
    #endif

    public init(settings: SwingFeedbackSettings) {
        self.settings = settings
    }

    deinit {
        if let audioInterruptionObserver {
            NotificationCenter.default.removeObserver(audioInterruptionObserver)
        }
    }

    /// Configures the audio session and prepares optional haptic hardware.
    public func prepare() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !prepared else { return }
        try prepareAudio()
        if settings.vibrationEnabled {
            try prepareHaptics()
        }
        prepared = true
    }

    /// Applies audio and vibration preferences without replacing the engine.
    public func update(settings: SwingFeedbackSettings) throws {
        lock.lock()
        defer { lock.unlock() }

        if settings.vibrationEnabled {
            try prepareHaptics()
        }
        self.settings = settings
        player.volume = settings.volume
    }

    /// Schedules the short tone and optional haptic for a swing signal.
    public func play(_ signal: SwingTempoSignal) throws {
        lock.lock()
        defer { lock.unlock() }

        guard prepared else {
            throw SwingFeedbackError.notPrepared
        }

        guard let kind = SwingTempoSignalKind(signal) else { return }
        if settings.soundEnabled {
            if audioInterrupted || !audioEngine.isRunning {
                try resumeAudio()
            }
            if let buffer = buffers[kind] {
                player.scheduleBuffer(
                    buffer,
                    at: AVAudioTime(hostTime: mach_absolute_time()),
                    options: []
                )
            }
        }
        if settings.vibrationEnabled {
            try playHaptic(for: kind)
        }
    }

    private func prepareAudio() throws {
        if !audioConfigured {
            let sampleRate = 44_100.0
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 1
            ) else {
                throw SwingFeedbackError.audioResourceUnavailable
            }

            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
            for kind in SwingTempoSignalKind.allCases {
                guard let buffer = makeBuffer(
                    frequency: kind.frequency,
                    format: format
                ) else {
                    throw SwingFeedbackError.audioResourceUnavailable
                }
                buffers[kind] = buffer
            }
            audioConfigured = true
        }

        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true)
        observeAudioInterruptions()
        #endif

        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        player.volume = settings.volume
        if !player.isPlaying {
            player.play()
        }
    }

    private func makeBuffer(
        frequency: Double,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 0.075)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ), let samples = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let fadeIn = min(1, Double(frame) / 160)
            let fadeOut = min(1, Double(Int(frameCount) - frame) / 320)
            let envelope = min(fadeIn, fadeOut)
            let sample = sin(2 * Double.pi * frequency * Double(frame) / sampleRate)
            samples[frame] = Float(sample * 0.35 * envelope)
        }
        return buffer
    }

    private func prepareHaptics() throws {
        #if os(iOS)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            throw SwingFeedbackError.hapticsUnavailable
        }
        if hapticsEngine == nil {
            let engine = try CHHapticEngine()
            engine.stoppedHandler = { [weak self] _ in
                self?.handleHapticsStopped()
            }
            engine.resetHandler = { [weak self, weak engine] in
                self?.recoverHaptics(using: engine)
            }
            hapticsEngine = engine
        }
        if !hapticsRunning, let hapticsEngine {
            try hapticsEngine.start()
            hapticsRunning = true
            hapticsRecoveryError = nil
        }
        #else
        throw SwingFeedbackError.hapticsUnavailable
        #endif
    }

    private func resumeAudio() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        if !player.isPlaying {
            player.play()
        }
        audioInterrupted = false
    }

    private func playHaptic(for kind: SwingTempoSignalKind) throws {
        #if os(iOS)
        guard let hapticsEngine else {
            throw SwingFeedbackError.hapticsUnavailable
        }
        if let hapticsRecoveryError {
            throw hapticsRecoveryError
        }
        if !hapticsRunning {
            try hapticsEngine.start()
            hapticsRunning = true
        }

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: kind.hapticIntensity
                ),
                CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: kind.hapticSharpness
                )
            ],
            relativeTime: 0
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let hapticPlayer = try hapticsEngine.makePlayer(with: pattern)
        try hapticPlayer.start(atTime: CHHapticTimeImmediate)
        #else
        throw SwingFeedbackError.hapticsUnavailable
        #endif
    }

    #if os(iOS)
    private func observeAudioInterruptions() {
        guard audioInterruptionObserver == nil else { return }
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        switch type {
        case .began:
            audioInterrupted = true
            player.pause()
            audioEngine.pause()
        case .ended:
            let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard options.contains(.shouldResume) else { return }
            do {
                try resumeAudio()
            } catch {
                errorHandler?(error)
            }
        @unknown default:
            return
        }
    }

    private func handleHapticsStopped() {
        lock.lock()
        hapticsRunning = false
        lock.unlock()
    }

    private func recoverHaptics(using engine: CHHapticEngine?) {
        guard let engine else { return }
        lock.lock()
        defer { lock.unlock() }
        do {
            try engine.start()
            hapticsRunning = true
            hapticsRecoveryError = nil
        } catch {
            hapticsRunning = false
            hapticsRecoveryError = error
        }
    }
    #endif
}

private enum SwingTempoSignalKind: CaseIterable, Hashable {
    case backswing
    case transition
    case impact

    init?(_ signal: SwingTempoSignal) {
        switch signal {
        case .backswingStarted:
            self = .backswing
        case .transitionStarted:
            self = .transition
        case .impact:
            self = .impact
        case .completed, .stopped:
            return nil
        }
    }

    var frequency: Double {
        switch self {
        case .backswing: 440
        case .transition: 660
        case .impact: 880
        }
    }

    var hapticIntensity: Float {
        switch self {
        case .backswing: 0.3
        case .transition: 0.6
        case .impact: 1
        }
    }

    var hapticSharpness: Float {
        switch self {
        case .backswing: 0.25
        case .transition: 0.55
        case .impact: 0.9
        }
    }
}
