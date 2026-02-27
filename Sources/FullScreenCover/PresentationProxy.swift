public import SwiftUI

/// A proxy that supports changing the presentations state of a modal view programmatically.
///
/// You don't create instances of `PresentationProxy` directly.
/// Instead, use a ``PresentationCoordinator`` in your view hierarchy to get an instance and pass it to  a ``FullScreenCoverModifier`` or the ``SwiftUICore/View/fullScreenCover(presentation:animation:content:)`` method.
@MainActor
public final class PresentationProxy: ObservableObject, Sendable {
    /// The current phase of the presentation lifecycle.
    @Published public private(set) var phase: PresentationPhase = .idle

    private let broadcast = AsyncBroadcast()

    @MainActor
    deinit {
        cancelAll()
    }

    /// Starts the transition to display the modal.
    ///
    /// This method returns once the phase has reached ``PresentationPhase/presented``.
    ///
    /// - If the phase is ``PresentationPhase/idle``, the transition starts immediately.
    /// - If the phase is ``PresentationPhase/presented``, this method returns immediately.
    /// - If the phase is ``PresentationPhase/presenting``, this method waits for the ongoing transition to complete.
    /// - If the phase is ``PresentationPhase/dismissing``, this method waits for the dismiss to finish, then starts a new presentation.
    ///
    /// - Note: If the calling task is cancelled, this method throws `CancellationError`,
    ///   but the transition itself continues unaffected.
    public func present() async throws {
        while true {
            switch phase {
            case .idle:
                phase = .presenting
                try await broadcast.wait()
                return
            case .presented:
                return
            case .presenting, .dismissing:
                try await broadcast.wait()
            }
        }
    }

    /// Starts the transition to dismiss the modal.
    ///
    /// This method returns once the phase has reached ``PresentationPhase/idle``.
    ///
    /// - If the phase is ``PresentationPhase/presented``, the transition starts immediately.
    /// - If the phase is ``PresentationPhase/idle``, this method returns immediately.
    /// - If the phase is ``PresentationPhase/dismissing``, this method waits for the ongoing transition to complete.
    /// - If the phase is ``PresentationPhase/presenting``, the presentation is cancelled and
    ///   the phase resets to ``PresentationPhase/idle``. Pending ``present()`` callers receive a `CancellationError`.
    ///
    /// - Note: If the calling task is cancelled, this method throws `CancellationError`,
    ///   but the transition itself continues unaffected.
    public func dismiss() async throws {
        while true {
            switch phase {
            case .presented:
                phase = .dismissing
                try await broadcast.wait()
                return
            case .idle:
                return
            case .dismissing:
                try await broadcast.wait()
            case .presenting:
                cancelPresentation()
                return
            }
        }
    }
}

public extension PresentationProxy {
    /// Whether the modal is currently presented or transitioning to be presented.
    ///
    /// This is a convenience property derived from ``phase``.
    /// It returns `true` when the phase is ``PresentationPhase/presenting`` or ``PresentationPhase/presented``.
    var isPresented: Bool {
        switch phase {
        case .idle, .dismissing:
            false
        case .presenting, .presented:
            true
        }
    }
}

extension PresentationProxy {
    func cancelAll() {
        broadcast.cancelAll()
        phase = .idle
    }

    func onWillPresent() {
        guard phase == .presenting else { return }
        phase = .presented
        broadcast.resumeAll()
    }

    func onDidDismiss() {
        guard phase == .dismissing else { return }
        phase = .idle
        broadcast.resumeAll()
    }
}

// MARK: - Private

private extension PresentationProxy {
    func cancelPresentation() {
        broadcast.cancelAll()
        phase = .idle
    }
}
