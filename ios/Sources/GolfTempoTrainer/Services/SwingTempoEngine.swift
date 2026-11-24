import Foundation

public enum SwingTempoEngineState: Equatable, Sendable {
    case idle
    case running
    case paused
}

public enum SwingTempoPhase: Equatable, Sendable {
    case idle
    case backswing
    case downswing
    case rest
}

public enum SwingTempoSignal: Equatable, Sendable {
    case backswingStarted(swingNumber: Int)
    case transitionStarted(swingNumber: Int)
    case impact(swingNumber: Int)
    case completed(totalSwings: Int)
    case stopped(completedSwings: Int)
}

public struct SwingTempoEngineSnapshot: Equatable, Sendable {
    public let state: SwingTempoEngineState
    public let phase: SwingTempoPhase
    public let currentSwing: Int
    public let completedSwings: Int
    public let remainingMilliseconds: Int

    fileprivate init(
        state: SwingTempoEngineState,
        phase: SwingTempoPhase,
        currentSwing: Int,
        completedSwings: Int,
        remainingMilliseconds: Int
    ) {
        self.state = state
        self.phase = phase
        self.currentSwing = currentSwing
        self.completedSwings = completedSwings
        self.remainingMilliseconds = remainingMilliseconds
    }
}

public enum SwingTempoEngineError: LocalizedError, Equatable {
    case alreadyActive
    case notRunning
    case notPaused

    public var errorDescription: String? {
        switch self {
        case .alreadyActive:
            "Ya hay una sesión de tempo activa."
        case .notRunning:
            "No hay una sesión en marcha para pausar."
        case .notPaused:
            "No hay una sesión pausada para reanudar."
        }
    }
}

/// Runs swing cues against monotonic absolute deadlines, independently of UI updates.
public actor SwingTempoEngine {
    private enum Stage {
        case backswing
        case downswing
        case rest
    }

    private let clock = ContinuousClock()
    private var state: SwingTempoEngineState = .idle
    private var phase: SwingTempoPhase = .idle
    private var stage: Stage?
    private var configuration: SwingWorkoutConfiguration?
    private var signalHandler: (@Sendable (SwingTempoSignal) -> Void)?
    private var task: Task<Void, Never>?
    private var currentDeadline: ContinuousClock.Instant?
    private var pausedRemainingDuration: Duration?
    private var currentSwing = 0
    private var completedSwings = 0
    private var generation: UInt64 = 0

    public init() {}

    /// Returns current phase and remaining time for presentation.
    public func snapshot() -> SwingTempoEngineSnapshot {
        SwingTempoEngineSnapshot(
            state: state,
            phase: phase,
            currentSwing: currentSwing,
            completedSwings: completedSwings,
            remainingMilliseconds: remainingDurationMilliseconds
        )
    }

    private var remainingDurationMilliseconds: Int {
        let duration: Duration
        if state == .paused, let pausedRemainingDuration {
            duration = pausedRemainingDuration
        } else if let currentDeadline {
            duration = clock.now.duration(to: currentDeadline)
        } else {
            return 0
        }

        let components = duration.components
        let nanoseconds = components.seconds * 1_000_000_000
            + components.attoseconds / 1_000_000_000
        guard nanoseconds > 0 else { return 0 }
        return Int((nanoseconds + 999_999) / 1_000_000)
    }

    /// Starts a finite workout and emits its first backswing signal immediately.
    public func start(
        configuration: SwingWorkoutConfiguration,
        onSignal: @escaping @Sendable (SwingTempoSignal) -> Void
    ) throws {
        guard state == .idle else {
            throw SwingTempoEngineError.alreadyActive
        }

        self.configuration = configuration
        signalHandler = onSignal
        state = .running
        currentSwing = 1
        completedSwings = 0
        stage = .backswing
        phase = .backswing

        onSignal(.backswingStarted(swingNumber: currentSwing))
        scheduleBoundary(
            at: clock.now.advanced(
                by: .milliseconds(
                    Int64(configuration.timing.backswingDurationMilliseconds)
                )
            )
        )
    }

    /// Pauses at the current phase and retains its remaining duration.
    public func pause() throws {
        guard state == .running, let currentDeadline else {
            throw SwingTempoEngineError.notRunning
        }

        let remaining = clock.now.duration(to: currentDeadline)
        pausedRemainingDuration = remaining > .zero ? remaining : .zero
        state = .paused
        generation &+= 1
        task?.cancel()
        task = nil
        self.currentDeadline = nil
    }

    /// Resumes the current phase without repeating its start signal.
    public func resume() throws {
        guard state == .paused, let pausedRemainingDuration else {
            throw SwingTempoEngineError.notPaused
        }

        state = .running
        self.pausedRemainingDuration = nil
        scheduleBoundary(at: clock.now.advanced(by: pausedRemainingDuration))
    }

    /// Cancels pending deadlines and returns the engine to idle.
    public func stop() {
        guard state != .idle else { return }

        let handler = signalHandler
        let stoppedCount = completedSwings
        generation &+= 1
        task?.cancel()
        task = nil
        currentDeadline = nil
        pausedRemainingDuration = nil
        configuration = nil
        signalHandler = nil
        stage = nil
        state = .idle
        phase = .idle
        currentSwing = 0
        handler?(.stopped(completedSwings: stoppedCount))
    }

    private func scheduleBoundary(at deadline: ContinuousClock.Instant) {
        generation &+= 1
        let scheduledGeneration = generation
        currentDeadline = deadline
        let clock = self.clock

        task = Task { [weak self, clock] in
            do {
                try await clock.sleep(
                    until: deadline,
                    tolerance: .milliseconds(1)
                )
            } catch {
                return
            }
            await self?.boundaryReached(
                generation: scheduledGeneration,
                deadline: deadline
            )
        }
    }

    private func boundaryReached(
        generation scheduledGeneration: UInt64,
        deadline: ContinuousClock.Instant
    ) {
        guard state == .running,
              generation == scheduledGeneration,
              let stage,
              let configuration else {
            return
        }

        task = nil
        currentDeadline = nil

        switch stage {
        case .backswing:
            self.stage = .downswing
            phase = .downswing
            signalHandler?(.transitionStarted(swingNumber: currentSwing))
            scheduleBoundary(
                at: deadline.advanced(
                    by: .milliseconds(
                        Int64(configuration.timing.downswingDurationMilliseconds)
                    )
                )
            )
        case .downswing:
            completedSwings = currentSwing
            signalHandler?(.impact(swingNumber: currentSwing))

            if completedSwings == configuration.repetitions {
                finish()
            } else if configuration.restBetweenSwingsMilliseconds > 0 {
                self.stage = .rest
                phase = .rest
                scheduleBoundary(
                    at: deadline.advanced(
                        by: .milliseconds(
                            Int64(configuration.restBetweenSwingsMilliseconds)
                        )
                    )
                )
            } else {
                beginNextSwing(at: deadline, configuration: configuration)
            }
        case .rest:
            beginNextSwing(at: deadline, configuration: configuration)
        }
    }

    private func beginNextSwing(
        at start: ContinuousClock.Instant,
        configuration: SwingWorkoutConfiguration
    ) {
        currentSwing += 1
        stage = .backswing
        phase = .backswing
        signalHandler?(.backswingStarted(swingNumber: currentSwing))
        scheduleBoundary(
            at: start.advanced(
                by: .milliseconds(
                    Int64(configuration.timing.backswingDurationMilliseconds)
                )
            )
        )
    }

    private func finish() {
        let handler = signalHandler
        let totalSwings = completedSwings
        task = nil
        currentDeadline = nil
        configuration = nil
        signalHandler = nil
        stage = nil
        state = .idle
        phase = .idle
        currentSwing = 0
        handler?(.completed(totalSwings: totalSwings))
    }
}
