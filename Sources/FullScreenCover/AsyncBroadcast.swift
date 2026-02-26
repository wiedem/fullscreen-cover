import Foundation

/// A broadcast primitive that allows multiple tasks to wait for a single event.
///
/// Multiple callers can suspend via ``wait()``. When the event occurs, all waiting
/// tasks are resumed simultaneously via ``resumeAll()``. Individual task cancellations
/// are handled automatically. Only the cancelled task is removed.
@MainActor
final class AsyncBroadcast: Sendable {
    private var continuations: [UUID: CheckedContinuation<Void, any Error>] = [:]

    /// Whether there are any tasks currently waiting.
    var isEmpty: Bool {
        continuations.isEmpty
    }

    deinit {
        for continuation in continuations.values {
            continuation.resume(throwing: CancellationError())
        }
    }

    /// Suspends the calling task until ``resumeAll()`` or ``cancelAll()`` is called.
    ///
    /// If the calling task is cancelled while waiting, it is automatically removed
    /// and resumed with a `CancellationError`. The transition itself is not affected.
    func wait() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuations[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                cancelContinuation(id: id)
            }
        }
    }

    /// Resumes all waiting tasks successfully.
    func resumeAll() {
        let snapshot = continuations
        continuations = [:]

        for continuation in snapshot.values {
            continuation.resume()
        }
    }

    /// Cancels all waiting tasks with a `CancellationError`.
    func cancelAll() {
        let snapshot = continuations
        continuations = [:]

        for continuation in snapshot.values {
            continuation.resume(throwing: CancellationError())
        }
    }
}

private extension AsyncBroadcast {
    func cancelContinuation(id: UUID) {
        guard let continuation = continuations.removeValue(forKey: id) else {
            return
        }
        continuation.resume(throwing: CancellationError())
    }
}
