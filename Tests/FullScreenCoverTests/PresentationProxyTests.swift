@testable import FullScreenCover
import Testing

@MainActor
@Suite("PresentationProxy")
struct PresentationProxyTests {
    // MARK: - Initial State

    @Test("Initial phase is idle")
    func initialState() {
        let proxy = PresentationProxy()
        #expect(proxy.phase == .idle)
        #expect(proxy.isPresented == false)
    }

    // MARK: - Phase Transitions

    @Test("present() transitions from idle to presenting, then presented after onWillPresent")
    func presentPhaseTransitions() async throws {
        let proxy = PresentationProxy()

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(proxy.phase == .presenting)
        #expect(proxy.isPresented == true)

        proxy.onWillPresent()
        try await presentResult

        #expect(proxy.phase == .presented)
        #expect(proxy.isPresented == true)
    }

    @Test("dismiss() transitions from presented to dismissing, then idle after onDidDismiss")
    func dismissPhaseTransitions() async throws {
        let proxy = PresentationProxy()

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        async let dismissResult: Void = proxy.dismiss()
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(proxy.phase == .dismissing)
        #expect(proxy.isPresented == false)

        proxy.onDidDismiss()
        try await dismissResult

        #expect(proxy.phase == .idle)
        #expect(proxy.isPresented == false)
    }

    // MARK: - No-Op Transitions

    @Test("present() is no-op when in presented phase")
    func presentIsNoOpWhenPresented() async throws {
        let proxy = PresentationProxy()

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        try await proxy.present()
        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() is no-op when in idle phase")
    func dismissIsNoOpWhenIdle() async throws {
        let proxy = PresentationProxy()
        try await proxy.dismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Joining an In-Progress Transition

    @Test("present() during presenting waits for presentation to complete")
    func presentWaitsDuringPresenting() async throws {
        let proxy = PresentationProxy()

        // Start presenting.
        async let firstPresent: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .presenting)

        // Second present should suspend and wait.
        let secondPresentTask = Task {
            try await proxy.present()
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .presenting)

        // Complete the presentation — both callers should finish.
        proxy.onWillPresent()
        try await firstPresent
        try await secondPresentTask.value

        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() during dismissing waits for dismiss to complete")
    func dismissWaitsDuringDismissing() async throws {
        let proxy = PresentationProxy()

        // Get to presented state.
        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        // Start dismissing.
        async let firstDismiss: Void = proxy.dismiss()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .dismissing)

        // Second dismiss should suspend and wait.
        let secondDismissTask = Task {
            try await proxy.dismiss()
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .dismissing)

        // Complete the dismiss — both callers should finish.
        proxy.onDidDismiss()
        try await firstDismiss
        try await secondDismissTask.value

        #expect(proxy.phase == .idle)
    }

    // MARK: - Cross-Phase Transitions

    @Test("present() during dismissing waits for dismiss then presents")
    func presentWaitsDuringDismissing() async throws {
        let proxy = PresentationProxy()

        // Present and reach .presented state.
        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        // Start dismissing.
        async let dismissResult: Void = proxy.dismiss()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .dismissing)

        // Call present() while dismissing — it should suspend and wait.
        let secondPresentTask = Task {
            try await proxy.present()
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        // Phase is still dismissing because present() is waiting.
        #expect(proxy.phase == .dismissing)

        // Complete the dismiss — this should unblock the pending present().
        proxy.onDidDismiss()
        try await dismissResult
        try await Task.sleep(nanoseconds: 10_000_000)

        // The pending present() should now be in presenting phase.
        #expect(proxy.phase == .presenting)
        #expect(proxy.isPresented == true)

        // Complete the presentation.
        proxy.onWillPresent()
        try await secondPresentTask.value

        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() during presenting cancels presentation and returns to idle")
    func dismissCancelsPresentationInProgress() async throws {
        let proxy = PresentationProxy()

        // Task returns true if present() threw CancellationError.
        let presentTask = Task { () -> Bool in
            do {
                try await proxy.present()
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .presenting)

        // dismiss() should cancel the pending present() and return immediately.
        try await proxy.dismiss()
        #expect(proxy.phase == .idle)
        #expect(proxy.isPresented == false)

        // Wait for the present task to finish processing the cancellation.
        let presentThrew = await presentTask.value
        #expect(presentThrew)
    }

    // MARK: - Task Cancellation

    @Test("present() throws CancellationError when task is cancelled, but transition continues")
    func presentThrowsOnTaskCancellation() async throws {
        let proxy = PresentationProxy()

        let task = Task { () -> Bool in
            do {
                try await proxy.present()
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .presenting)

        task.cancel()

        let threw = await task.value
        #expect(threw)

        // Allow the cancel handler's MainActor task to process.
        try await Task.sleep(nanoseconds: 10_000_000)

        // Transition continues despite task cancellation — no rollback.
        #expect(proxy.phase == .presenting)
        #expect(proxy.isPresented == true)

        // The transition completes normally when the callback fires.
        proxy.onWillPresent()
        #expect(proxy.phase == .presented)
    }

    @Test("dismiss() throws CancellationError when task is cancelled, but transition continues")
    func dismissThrowsOnTaskCancellation() async throws {
        let proxy = PresentationProxy()

        // Get to presented state.
        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        let task = Task { () -> Bool in
            do {
                try await proxy.dismiss()
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .dismissing)

        task.cancel()

        let threw = await task.value
        #expect(threw)

        // Allow the cancel handler's MainActor task to process.
        try await Task.sleep(nanoseconds: 10_000_000)

        // Transition continues despite task cancellation — no rollback.
        #expect(proxy.phase == .dismissing)
        #expect(proxy.isPresented == false)

        // The transition completes normally when the callback fires.
        proxy.onDidDismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Continuation Callbacks

    @Test("onWillPresent() resumes continuation and sets phase to presented")
    func onWillPresentResumesContinuation() async throws {
        let proxy = PresentationProxy()

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)

        proxy.onWillPresent()
        try await presentResult

        #expect(proxy.phase == .presented)
    }

    @Test("onDidDismiss() resumes continuation and sets phase to idle")
    func onDidDismissResumesContinuation() async throws {
        let proxy = PresentationProxy()

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        proxy.onWillPresent()
        try await presentResult

        async let dismissResult: Void = proxy.dismiss()
        try await Task.sleep(nanoseconds: 10_000_000)

        proxy.onDidDismiss()
        try await dismissResult

        #expect(proxy.phase == .idle)
    }

    @Test("onWillPresent() is no-op without pending continuation")
    func onWillPresentNoOpWithoutContinuation() {
        let proxy = PresentationProxy()
        proxy.onWillPresent()
        #expect(proxy.phase == .idle)
    }

    @Test("onDidDismiss() is no-op without pending continuation")
    func onDidDismissNoOpWithoutContinuation() {
        let proxy = PresentationProxy()
        proxy.onDidDismiss()
        #expect(proxy.phase == .idle)
    }

    // MARK: - Full Lifecycle

    @Test("Full lifecycle: idle → presenting → presented → dismissing → idle")
    func fullLifecycle() async throws {
        let proxy = PresentationProxy()
        #expect(proxy.phase == .idle)

        async let presentResult: Void = proxy.present()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .presenting)

        proxy.onWillPresent()
        try await presentResult
        #expect(proxy.phase == .presented)

        async let dismissResult: Void = proxy.dismiss()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(proxy.phase == .dismissing)

        proxy.onDidDismiss()
        try await dismissResult
        #expect(proxy.phase == .idle)
    }
}
