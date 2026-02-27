@testable import FullScreenCover
import Testing

@MainActor
@Suite("PresentationProxy")
final class PresentationProxyTests {
    private let proxy = PresentationProxy()

    @MainActor
    deinit {
        proxy.cancelAll()
    }

    // MARK: - Initial State

    @Test("Initial phase is idle")
    func initialState() {
        #expect(proxy.phase == .idle)
        #expect(proxy.isPresented == false)
    }

    // MARK: - Phase Transitions

    @Test("present() transitions from idle to presenting, then presented after onWillPresent")
    func presentPhaseTransitions() async throws {
        // Collect all three expected phase values.
        let phases = collectValues(from: proxy.$phase, max: 3)

        // Wait for the next phase change after idle.
        let nextPhaseTask = collectValues(from: proxy.$phase.dropFirst(), max: 1)

        // Start presenting.
        Task { try await proxy.present() }

        // Verify the phase changed to presenting.
        let nextPhase = try #require(try await nextPhaseTask.value.first)
        #expect(nextPhase == .presenting)

        // Complete the presentation.
        proxy.onWillPresent()

        // Verify the full phase transition sequence.
        #expect(try await phases.value == [.idle, .presenting, .presented])
    }

    @Test("dismiss() transitions from presented to dismissing, then idle after onDidDismiss")
    func dismissPhaseTransitions() async throws {
        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Collect all expected phase values from presented onward.
        let phases = collectValues(from: proxy.$phase, max: 3)

        // Wait for the next phase change after presented.
        let nextPhaseTask = collectValues(from: proxy.$phase.dropFirst(), max: 1)

        // Start dismissing.
        Task { try await proxy.dismiss() }

        // Verify the phase changed to dismissing.
        let nextPhase = try #require(try await nextPhaseTask.value.first)
        #expect(nextPhase == .dismissing)
        #expect(proxy.isPresented == false)

        // Complete the dismiss.
        proxy.onDidDismiss()

        // Verify the full phase transition sequence.
        #expect(try await phases.value == [.presented, .dismissing, .idle])
        #expect(proxy.isPresented == false)
    }

    // MARK: - No-Op Transitions

    @Test("present() is no-op when in presented phase")
    func presentIsNoOpWhenPresented() async throws {
        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Calling present() again should be a no-op.
        try await proxy.present()
        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() is no-op when in idle phase")
    func dismissIsNoOpWhenIdle() async throws {
        try await proxy.dismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Joining an In-Progress Transition

    @Test("present() during presenting waits for presentation to complete")
    func presentWaitsDuringPresenting() async throws {
        // Start presenting.
        let firstTask = try await Self.startPresenting(proxy)

        // Second present should suspend and wait - no phase change.
        let secondTask = Task { try await proxy.present() }
        #expect(proxy.phase == .presenting)

        // Complete the presentation - both callers should finish.
        proxy.onWillPresent()
        try await firstTask.value
        try await secondTask.value

        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() during dismissing waits for dismiss to complete")
    func dismissWaitsDuringDismissing() async throws {
        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Start dismissing.
        let firstTask = try await Self.startDismissing(proxy)

        // Second dismiss should suspend and wait - no phase change.
        let secondTask = Task { try await proxy.dismiss() }
        #expect(proxy.phase == .dismissing)

        // Complete the dismiss - both callers should finish.
        proxy.onDidDismiss()
        try await firstTask.value
        try await secondTask.value

        #expect(proxy.phase == .idle)
    }

    // MARK: - Cross-Phase Transitions

    @Test("present() during dismissing waits for dismiss then presents")
    func presentWaitsDuringDismissing() async throws {
        // Collect all expected phases: idle -> presenting -> presented -> dismissing -> idle -> presenting.
        let allPhases = collectValues(from: proxy.$phase, max: 6)

        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Start dismissing.
        let dismissTask = try await Self.startDismissing(proxy)

        // Call present() while dismissing - it should suspend and wait.
        let secondPresentTask = Task { try await proxy.present() }

        // Complete the dismiss - this should unblock the pending present().
        proxy.onDidDismiss()
        try await dismissTask.value

        // Wait for the re-presentation to reach presenting.
        let phases = try await allPhases.value
        #expect(phases == [.idle, .presenting, .presented, .dismissing, .idle, .presenting])
        #expect(proxy.isPresented == true)

        // Complete the re-presentation.
        proxy.onWillPresent()
        try await secondPresentTask.value

        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() during presenting cancels presentation and returns to idle")
    func dismissCancelsPresentationInProgress() async throws {
        // Start presenting.
        let presentTask = try await Self.startPresenting(proxy)

        // dismiss() should cancel the pending present() and return immediately.
        try await proxy.dismiss()
        #expect(proxy.phase == .idle)
        #expect(proxy.isPresented == false)

        // The present task should have been cancelled.
        let result = await presentTask.result
        #expect(throws: CancellationError.self) { try result.get() }
    }

    // MARK: - Task Cancellation

    @Test("present() throws CancellationError when task is cancelled, but transition continues")
    func presentThrowsOnTaskCancellation() async throws {
        // Start presenting.
        let task = try await Self.startPresenting(proxy)

        // Cancel the task.
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }

        // Transition continues despite task cancellation - no rollback.
        #expect(proxy.phase == .presenting)
        #expect(proxy.isPresented == true)

        // The transition completes normally when the callback fires.
        proxy.onWillPresent()
        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() throws CancellationError when task is cancelled, but transition continues")
    func dismissThrowsOnTaskCancellation() async throws {
        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Start dismissing.
        let task = try await Self.startDismissing(proxy)

        // Cancel the task.
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }

        // Transition continues despite task cancellation - no rollback.
        #expect(proxy.phase == .dismissing)
        #expect(proxy.isPresented == false)

        // The transition completes normally when the callback fires.
        proxy.onDidDismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Continuation Callbacks

    @Test("onWillPresent() resumes continuation and sets phase to presented")
    func onWillPresentResumesContinuation() async throws {
        // Start presenting.
        let task = try await Self.startPresenting(proxy)

        // Complete the presentation.
        proxy.onWillPresent()
        try await task.value

        #expect(proxy.phase == .presented)
    }

    @Test("onDidDismiss() resumes continuation and sets phase to idle")
    func onDidDismissResumesContinuation() async throws {
        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Start dismissing.
        let task = try await Self.startDismissing(proxy)

        // Complete the dismiss.
        proxy.onDidDismiss()
        try await task.value

        #expect(proxy.phase == .idle)
    }

    @Test("onWillPresent() is no-op without pending continuation")
    func onWillPresentNoOpWithoutContinuation() {
        proxy.onWillPresent()
        #expect(proxy.phase == .idle)
    }

    @Test("onDidDismiss() is no-op without pending continuation")
    func onDidDismissNoOpWithoutContinuation() {
        proxy.onDidDismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Full Lifecycle

    @Test("Full lifecycle: idle -> presenting -> presented -> dismissing -> idle")
    func fullLifecycle() async throws {
        // Collect all five expected phase values.
        let phases = collectValues(from: proxy.$phase, max: 5)

        // Reach presented state.
        try await Self.reachPresentedState(proxy)

        // Start dismissing.
        try await Self.startDismissing(proxy)

        // Complete the dismiss.
        proxy.onDidDismiss()

        // Verify the full lifecycle sequence.
        #expect(try await phases.value == [.idle, .presenting, .presented, .dismissing, .idle])
    }
}

// MARK: - Private Helpers

private extension PresentationProxyTests {
    /// Starts presenting and waits until the phase reaches `.presenting`.
    @discardableResult
    static func startPresenting(_ proxy: PresentationProxy) async throws -> Task<Void, any Error> {
        let presentingPhase = collectValues(from: proxy.$phase.dropFirst(), max: 1)
        let task = Task { try await proxy.present() }
        _ = try await presentingPhase.value
        return task
    }

    /// Starts dismissing and waits until the phase reaches `.dismissing`.
    @discardableResult
    static func startDismissing(_ proxy: PresentationProxy) async throws -> Task<Void, any Error> {
        let dismissingPhase = collectValues(from: proxy.$phase.dropFirst(), max: 1)
        let task = Task { try await proxy.dismiss() }
        _ = try await dismissingPhase.value
        return task
    }

    /// Transitions the proxy from idle to presented.
    static func reachPresentedState(_ proxy: PresentationProxy) async throws {
        try await startPresenting(proxy)
        proxy.onWillPresent()
    }
}
