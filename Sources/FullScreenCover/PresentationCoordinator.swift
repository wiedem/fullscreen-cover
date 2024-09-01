import SwiftUI

/// A view that provides programmatic coordination of modal transitions, by working with a proxy to present and dismiss modal full-screen views.
///
/// The presentation coordinator's content view builder receives a ``PresentationProxy`` instance.
/// Use the ``PresentationProxy/present()`` and ``PresentationProxy/dismiss()`` methods to trigger modal transitions.
///
/// ```swift
/// var body: some View {
///     PresentationCoordinator { proxy in
///         VStack {
///             Button("Present Modal") {
///                 Task {
///                     try await proxy.present()
///                 }
///             }
///         }
///         .fullScreenCover(presentation: proxy, animation: .easeIn) {
///             VStack {
///                 Text("Full-screen modal content")
///                     .font(.title)
///
///                 Button("Dismiss") {
///                     Task {
///                         try await proxy.dismiss()
///                     }
///                 }
///             }
///             .transition(.opacity)
///         }
///     }
/// }
/// ```
@MainActor
public struct PresentationCoordinator<Content>: View where Content: View {
    @StateObject private var presentationProxy = PresentationProxy()

    private let content: (PresentationProxy) -> Content

    public var body: some View {
        content(presentationProxy)
    }

    /// Creates an instance that can coordinate the modal full-screen presentations used by its child views.
    ///
    /// - Parameter content: The content from which a full-screen modal transition can be triggered.
    public init(@ViewBuilder content: @escaping (PresentationProxy) -> Content) {
        self.content = content
    }
}
