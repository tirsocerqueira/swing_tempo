import Foundation
import Observation

public enum TrainerDisplayPhase: Equatable {
    case ready
    case backswing
    case transition
    case downswing
    case rest
}

@MainActor
@Observable
public final class TempoTrainerViewModel {
    public var selectedPreset: SwingTempoPreset = .threeToOne
    public var totalDurationMilliseconds = 1_250.0
    public var repetitions = 10
    public var restBetweenSwingsMilliseconds = 0
    public var customRatio = 3.0
    public var usesCustomRatio = false
    public private(set) var workoutType: WorkoutType = .warmup
    public private(set) var engineState: SwingTempoEngineState = .idle
    public private(set) var phase: TrainerDisplayPhase = .ready
    public private(set) var currentSwing = 0
    public private(set) var completedSwings = 0
    public private(set) var remainingMilliseconds = 0
    public var errorMessage: String?
    public var onWorkoutCompleted: (@MainActor (CompletedWorkout) -> Void)?

    private let engine: SwingTempoEngine
    private let feedback: SwingFeedbackService
    private let clock = ContinuousClock()
    private var progressTask: Task<Void, Never>?
    private var transitionDisplayTask: Task<Void, Never>?
    private var activeTiming: SwingTiming?
    private var activeWorkoutType: WorkoutType?
    private var startedAt: ContinuousClock.Instant?
    private var startedAtDate: Date?

    public init(
        engine: SwingTempoEngine = SwingTempoEngine(),
        feedback: SwingFeedbackService = SwingFeedbackService(
            settings: .standard
        )
    ) {
        self.engine = engine
        self.feedback = feedback
        feedback.errorHandler = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    public var isRunning: Bool { engineState == .running }
    public var isPaused: Bool { engineState == .paused }
    public var isIdle: Bool { engineState == .idle }

    public var primaryActionTitle: String {
        switch engineState {
        case .idle: "START"
        case .running: "PAUSE"
        case .paused: "RESUME"
        }
    }

    public var phaseDurationMilliseconds: Int {
        if phase == .rest {
            return restBetweenSwingsMilliseconds
        }
        let total = Int(totalDurationMilliseconds)
        let ratio = currentRatio
        let backswing = Int(
            (Double(total) * ratio / (ratio + 1)).rounded()
        )
        return phase == .downswing || phase == .transition
            ? total - backswing
            : backswing
    }

    public var currentRatio: Double {
        usesCustomRatio ? customRatio : selectedPreset.backswingToDownswingRatio
    }

    public func select(_ workout: GuidedWorkout) {
        repetitions = workout.repetitions
        usesCustomRatio = false
        workoutType = workout.type
    }

    public func selectFreePractice() {
        workoutType = .freePractice
        usesCustomRatio = true
    }

    public func performPrimaryAction() async {
        do {
            switch engineState {
            case .idle:
                try await startWorkout()
            case .running:
                try await engine.pause()
                progressTask?.cancel()
                progressTask = nil
                transitionDisplayTask?.cancel()
                apply(await engine.snapshot())
                if phase == .transition {
                    phase = .downswing
                }
            case .paused:
                try await engine.resume()
                apply(await engine.snapshot())
                startProgressUpdates()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stop() async {
        await engine.stop()
        progressTask?.cancel()
        progressTask = nil
        transitionDisplayTask?.cancel()
        apply(await engine.snapshot())
    }

    public func clearError() {
        errorMessage = nil
    }

    public func updateFeedbackSettings(
        _ settings: SwingFeedbackSettings
    ) throws {
        try feedback.update(settings: settings)
    }

    private func startWorkout() async throws {
        let timing = try SwingTiming(
            totalDurationMilliseconds: Int(totalDurationMilliseconds),
            backswingToDownswingRatio: currentRatio
        )
        let configuration = try SwingWorkoutConfiguration(
            timing: timing,
            repetitions: repetitions,
            restBetweenSwingsMilliseconds: restBetweenSwingsMilliseconds,
            workoutType: workoutType
        )
        try feedback.prepare()
        try await engine.start(configuration: configuration) { [weak self, feedback] signal in
            do {
                try feedback.play(signal)
            } catch {
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
            Task { @MainActor [weak self] in
                self?.receive(signal)
            }
        }
        activeTiming = timing
        activeWorkoutType = workoutType
        startedAt = clock.now
        startedAtDate = Date()
        engineState = .running
        startProgressUpdates()
    }

    private func receive(_ signal: SwingTempoSignal) {
        switch signal {
        case .backswingStarted(let swingNumber):
            transitionDisplayTask?.cancel()
            phase = .backswing
            currentSwing = swingNumber
            remainingMilliseconds = phaseDurationMilliseconds
        case .transitionStarted:
            phase = .transition
            remainingMilliseconds = phaseDurationMilliseconds
            showDownswingAfterTransition()
        case .impact(let swingNumber):
            completedSwings = swingNumber
        case .completed(let totalSwings):
            progressTask?.cancel()
            progressTask = nil
            transitionDisplayTask?.cancel()
            if let activeTiming, let activeWorkoutType,
               let startedAt, let startedAtDate {
                let elapsed = startedAt.duration(to: clock.now).components
                let durationSeconds = Double(elapsed.seconds)
                    + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
                onWorkoutCompleted?(
                    CompletedWorkout(
                        date: startedAtDate,
                        timing: activeTiming,
                        swingCount: totalSwings,
                        durationSeconds: durationSeconds,
                        workoutType: activeWorkoutType
                    )
                )
            }
            clearActiveWorkout()
            phase = .ready
            engineState = .idle
            remainingMilliseconds = 0
        case .stopped:
            clearActiveWorkout()
            transitionDisplayTask?.cancel()
            phase = .ready
            engineState = .idle
            currentSwing = 0
            remainingMilliseconds = 0
        }
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        let engine = engine
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                let snapshot = await engine.snapshot()
                guard let self else { return }
                apply(snapshot)
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch is CancellationError {
                    return
                } catch {
                    self.errorMessage = error.localizedDescription
                    return
                }
            }
        }
    }

    private func showDownswingAfterTransition() {
        transitionDisplayTask?.cancel()
        transitionDisplayTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
                return
            }
            guard let self, phase == .transition else { return }
            phase = .downswing
        }
    }

    private func apply(_ snapshot: SwingTempoEngineSnapshot) {
        engineState = snapshot.state
        currentSwing = snapshot.currentSwing
        completedSwings = snapshot.completedSwings
        remainingMilliseconds = snapshot.remainingMilliseconds
        switch snapshot.phase {
        case .idle: phase = .ready
        case .backswing: phase = .backswing
        case .downswing:
            if phase != .transition {
                phase = .downswing
            }
        case .rest: phase = .rest
        }
    }

    private func clearActiveWorkout() {
        activeTiming = nil
        activeWorkoutType = nil
        startedAt = nil
        startedAtDate = nil
    }
}
