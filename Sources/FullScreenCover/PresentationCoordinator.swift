public import SwiftUI

/// A view that provides programmatic coordination of modal transitions, by working with a proxy to present and dismiss modal full-screen views.
///
/// The presentation coordinator's content view builder receives a ``PresentationProxy`` instance.
/// Use the ``PresentationProxy/present()`` and ``PresentationProxy/dismiss()`` methods to trigger modal transitions.
///
/// ```swift
/// var body: some View {
///     PresentationCoordinator { proxy in
///         Button("Present Modal") {
///             Task { try await proxy.present() }
///         }
///         .fullScreenCover(presentation: proxy, animation: .spring(duration: 0.5)) {
///             ZStack {
///                 Color.black.opacity(0.5)
///                     .ignoresSafeArea()
///
///                 Text("Custom modal content")
///                     .font(.title)
///             }
///             .presentationBackground(Color.clear)
///             .transition(.scale(scale: 0.8).combined(with: .opacity))
///         }
///     }
/// }
/// ```
///
/// - Note: The ``PresentationProxy`` instance is automatically made available to the subviews of the content view and can be accessed with an [EnvironmentObject](https://developer.apple.com/documentation/swiftui/environmentobject) property wrapper.
@MainActor
public struct PresentationCoordinator<Content: View>: View {
    @StateObject private var presentationProxy = PresentationProxy()

    private let content: (PresentationProxy) -> Content

    public var body: some View {
        content(presentationProxy)
            .environmentObject(presentationProxy)
            .onDisappear {
                presentationProxy.cancelAll()
            }
    }

    /// Creates an instance that can coordinate the modal full-screen presentations used by its child views.
    ///
    /// - Parameter content: The content from which a full-screen modal transition can be triggered.
    public init(@ViewBuilder content: @escaping (PresentationProxy) -> Content) {
        self.content = content
    }
}

// MARK: - Preview

#Preview("Custom Transition") {
    PresentationCoordinator { proxy in
        VStack(spacing: 20) {
            Text("Custom Scale + Fade Transition")
                .font(.headline)

            Button("Present Modal") {
                Task {
                    try await proxy.present()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .fullScreenCover(presentation: proxy, animation: .spring(duration: 0.5, bounce: 0.2)) {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Success!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("This modal uses a custom scale + fade transition\ninstead of the default slide-up animation.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))

                    Button("Dismiss") {
                        Task {
                            try await proxy.dismiss()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding()
            }
            .presentationBackground(Color.clear)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

#Preview("Async Coordination") {
    struct ChainedPresentationDemo: View {
        @State private var status = "Tap the button to start"

        var body: some View {
            PresentationCoordinator { proxy in
                VStack(spacing: 20) {
                    Text("Async Coordination")
                        .font(.headline)

                    Text(status)
                        .foregroundStyle(.secondary)

                    Button("Show Confirmation Flow") {
                        Task {
                            // Step 1: Present the modal and wait
                            status = "Modal is visible…"
                            try await proxy.present()

                            // Step 2: Simulate a delay, then dismiss and wait for completion
                            try await Task.sleep(for: .seconds(2))
                            status = "Dismissing…"
                            try await proxy.dismiss()

                            // Step 3: Only runs after dismiss animation is fully complete
                            status = "Dismiss complete - safe to continue!"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .fullScreenCover(presentation: proxy, animation: .easeInOut(duration: 0.4)) {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)

                            Text("Processing…")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("This modal will auto-dismiss in 2 seconds.\nThe caller awaits completion before continuing.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                    }
                    .presentationBackground(Color.clear)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    return ChainedPresentationDemo()
}
