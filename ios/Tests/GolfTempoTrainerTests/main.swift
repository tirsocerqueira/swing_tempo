import Foundation
import GolfTempoTrainer

private final class SignalCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSignals: [SwingTempoSignal] = []

    func append(_ signal: SwingTempoSignal) {
        lock.lock()
        storedSignals.append(signal)
        lock.unlock()
    }

    var signals: [SwingTempoSignal] {
        lock.lock()
        defer { lock.unlock() }
        return storedSignals
    }
}

@main
private struct GolfTempoTrainerTests {
    static func main() async throws {
        try testPresetsKeepTheirRatioWhenTotalDurationChanges()
        try testFourToOnePresetMatchesDefaultDurations()
        try testTimingRejectsInvalidInputs()
        try testGuidedWorkoutRepetitions()
        try await testEngineProducesSignalsInOrder()
        try await testPauseAndResumePreservePhase()
        try await testStopCancelsPendingPhase()
        print("All GolfTempoTrainer tests passed.")
    }

    private static func testPresetsKeepTheirRatioWhenTotalDurationChanges() throws {
        for preset in SwingTempoPreset.allCases {
            let timing = try preset.timing(totalDurationMilliseconds: 1_250)
            let sum = timing.backswingDurationMilliseconds
                + timing.downswingDurationMilliseconds
            let ratio = Double(timing.backswingDurationMilliseconds)
                / Double(timing.downswingDurationMilliseconds)

            try expect(sum == 1_250, "Tempo intervals must sum to the total.")
            try expect(
                abs(ratio - preset.backswingToDownswingRatio) < 0.01,
                "Tempo ratio must be preserved."
            )
        }
    }

    private static func testFourToOnePresetMatchesDefaultDurations() throws {
        let timing = try SwingTempoPreset.fourToOne
            .timing(totalDurationMilliseconds: 1_250)

        try expect(
            timing.backswingDurationMilliseconds == 1_000
                && timing.downswingDurationMilliseconds == 250,
            "The 4:1 preset must match the specified default intervals."
        )
    }

    private static func testThreeToOnePresetIsDefaultTempo() throws {
        let timing = try SwingTempoPreset.threeToOne
            .timing(totalDurationMilliseconds: 1_250)

        try expect(
            timing.backswingDurationMilliseconds == 938
                && timing.downswingDurationMilliseconds == 312,
            "The default 3:1 tempo must split 1250 ms proportionally."
        )
    }

    private static func testTimingRejectsInvalidInputs() throws {
        do {
            _ = try SwingTiming(
                totalDurationMilliseconds: 0,
                backswingToDownswingRatio: 2
            )
            throw TestFailure(description: "Zero duration should be rejected.")
        } catch is SwingTimingError {
        }

        do {
            _ = try SwingTiming(
                totalDurationMilliseconds: 1_250,
                backswingToDownswingRatio: .infinity
            )
            throw TestFailure(
                description: "Infinite ratio should be rejected."
            )
        } catch is SwingTimingError {
        }

        do {
            _ = try SwingTiming(
                totalDurationMilliseconds: 1,
                backswingToDownswingRatio: 4
            )
            throw TestFailure(
                description: "A phase shorter than one millisecond should be rejected."
            )
        } catch is SwingTimingError {
        }
    }

    private static func testGuidedWorkoutRepetitions() throws {
        let expected = [10, 20, 30, 50]
        try expect(
            GuidedWorkout.presets.map(\.repetitions) == expected,
            "Guided workout presets must have their specified repetition counts."
        )
    }

    private static func testEngineProducesSignalsInOrder() async throws {
        let timing = try SwingTempoPreset.twoToOne
            .timing(totalDurationMilliseconds: 30)
        let configuration = try SwingWorkoutConfiguration(
            timing: timing,
            repetitions: 2,
            restBetweenSwingsMilliseconds: 5
        )
        let collector = SignalCollector()
        let engine = SwingTempoEngine()

        try await engine.start(configuration: configuration) {
            collector.append($0)
        }
        try await Task.sleep(for: .milliseconds(250))

        let expected: [SwingTempoSignal] = [
            .backswingStarted(swingNumber: 1),
            .transitionStarted(swingNumber: 1),
            .impact(swingNumber: 1),
            .backswingStarted(swingNumber: 2),
            .transitionStarted(swingNumber: 2),
            .impact(swingNumber: 2),
            .completed(totalSwings: 2)
        ]
        try expect(collector.signals == expected, "Swing signals must be ordered.")
        let finishedSnapshot = await engine.snapshot()
        try expect(
            finishedSnapshot.state == .idle,
            "The engine must return to idle after completion."
        )
    }

    private static func testPauseAndResumePreservePhase() async throws {
        let timing = try SwingTempoPreset.twoToOne
            .timing(totalDurationMilliseconds: 120)
        let configuration = try SwingWorkoutConfiguration(
            timing: timing,
            repetitions: 1
        )
        let collector = SignalCollector()
        let engine = SwingTempoEngine()

        try await engine.start(configuration: configuration) {
            collector.append($0)
        }
        try await Task.sleep(for: .milliseconds(10))
        try await engine.pause()
        let pausedSnapshot = await engine.snapshot()
        try await Task.sleep(for: .milliseconds(100))
        try expect(
            collector.signals == [.backswingStarted(swingNumber: 1)],
            "A paused engine must not emit phase signals."
        )
        try expect(
            pausedSnapshot.state == .paused && pausedSnapshot.phase == .backswing,
            "Pause must preserve the current phase."
        )

        try await engine.resume()
        try await Task.sleep(for: .milliseconds(250))
        try expect(
            collector.signals.contains(.completed(totalSwings: 1)),
            "A resumed engine must complete the swing."
        )
    }

    private static func testStopCancelsPendingPhase() async throws {
        let timing = try SwingTempoPreset.fourToOne
            .timing(totalDurationMilliseconds: 1_000)
        let configuration = try SwingWorkoutConfiguration(
            timing: timing,
            repetitions: 5
        )
        let collector = SignalCollector()
        let engine = SwingTempoEngine()

        try await engine.start(configuration: configuration) {
            collector.append($0)
        }
        await engine.stop()
        try await Task.sleep(for: .milliseconds(10))

        try expect(
            collector.signals == [
                .backswingStarted(swingNumber: 1),
                .stopped(completedSwings: 0)
            ],
            "Stopping must cancel the pending phase."
        )
        let stoppedSnapshot = await engine.snapshot()
        try expect(
            stoppedSnapshot.state == .idle,
            "A stopped engine must be idle."
        )
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw TestFailure(description: message)
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(description: String) {
        self.description = description
    }
}
