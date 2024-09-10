import SwiftUI

/// A proxy that supports changing the presentations state of a modal view programmatically.
///
/// You don't create instances of `PresentationProxy` directly.
/// Instead, use a ``PresentationCoordinator`` in your view hierarchy to get an instance and pass it to  a ``FullScreenCoverModifier`` or the ``SwiftUICore/View/fullScreenCover(presentation:animation:content:)`` method.
@MainActor
public final class PresentationProxy: ObservableObject, Sendable {
    @Published public private(set) var isPresented: Bool = false
    private var presentationContinuation: CheckedContinuation<Void, any Error>?
    private var dismissContinuation: CheckedContinuation<Void, any Error>?

    deinit {
        if let presentationContinuation {
            self.presentationContinuation = nil
            presentationContinuation.resume(throwing: CancellationError())
        }
        if let dismissContinuation {
            self.dismissContinuation = nil
            dismissContinuation.resume(throwing: CancellationError())
        }
    }

    /// Starts the transition to display the modal.
    ///
    /// This method returns before the modal content and the associated transition are displayed.
    ///
    /// - Note: This method throws a `CancellationError` if the modal view is currently visible or in the process of becoming visible.
    public func present() async throws {
        guard isPresented == false, presentationContinuation == nil else {
            throw CancellationError()
        }

        try await withCheckedThrowingContinuation { continuation in
            presentationContinuation = continuation
            isPresented = true
        }
    }

    /// Starts the transition to dismiss the modal.
    ///
    /// This method returns after the modal content is no longer visible and the associated transition has been completed.
    ///
    /// Running appearance transitions triggered by ``present()`` are not aborted by a call to `dismiss`.
    /// If `dismiss` is called while a transition triggered by ``present()`` is still running, the modal view automatically executes the dismiss transition once the appearance transition has been completed.
    ///
    /// - Note: This method throws a `CancellationError` if the modal view is currently not visible or in the process of becoming dismissed.
    public func dismiss() async throws {
        guard isPresented, dismissContinuation == nil else {
            throw CancellationError()
        }

        try await withCheckedThrowingContinuation { continuation in
            dismissContinuation = continuation
            isPresented = false
        }
    }
}

extension PresentationProxy {
    func onWillPresent() {
        guard let presentationContinuation else { return }
        self.presentationContinuation = nil
        presentationContinuation.resume()
    }

    func onDidDismiss() {
        guard let dismissContinuation else { return }
        self.dismissContinuation = nil
        dismissContinuation.resume()
    }
}
