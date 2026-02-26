/// The current phase of the presentation lifecycle managed by a ``PresentationProxy``.
public enum PresentationPhase: Sendable {
    /// No modal is active.
    case idle
    /// A presentation transition is in progress. Waiting for the modal content to appear.
    case presenting
    /// The modal is visible.
    case presented
    /// A dismiss transition is in progress. Waiting for the modal content to disappear.
    case dismissing
}
