public import SwiftUI

struct FullScreenCoverModifier<ModalContent: View>: ViewModifier {
    @State private var isSheetPresented: Bool
    @State private var showModalContent = false
    @ObservedObject private var presentationProxy: PresentationProxy

    @ViewBuilder private let modalContent: () -> ModalContent

    private let animation: Animation?

    func body(content: Content) -> some View {
        // A ZStack isolates the .fullScreenCover trigger from the content view,
        // preventing safe area insets from propagating to the content.
        ZStack {
            Color.clear
                .frame(width: 0, height: 0)
                .fullScreenCover(
                    isPresented: $isSheetPresented,
                    onDismiss: {
                        presentationProxy.onDidDismiss()
                    }
                ) {
                    Group {
                        if showModalContent {
                            modalContent()
                                .task {
                                    // The modal content has appeared. Notify the proxy so that present() callers are resumed.
                                    presentationProxy.onWillPresent()
                                }
                                .onDisappear {
                                    // The custom dismiss animation has finished. Close the native container so that onDismiss fires.
                                    guard isSheetPresented else { return }
                                    isSheetPresented = false
                                }
                        }
                    }
                    .task {
                        // The native container has appeared. Check whether the proxy still wants to present.
                        // A rapid present/dismiss could have changed the state before the container was ready.
                        guard !showModalContent else { return }
                        guard presentationProxy.isPresented else {
                            isSheetPresented = false
                            return
                        }

                        showModalContent = true
                    }
                }
                .onChange(of: presentationProxy.isPresented) { newValue in
                    if newValue {
                        // Suppress the native slide-up animation. The custom transition is driven by showModalContent.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isSheetPresented = true
                        }
                    } else {
                        guard showModalContent else {
                            // Content never appeared. Close the container directly.
                            isSheetPresented = false
                            return
                        }

                        // Hide the content first to trigger the custom dismiss animation. Once it finishes,
                        // onDisappear closes the native container.
                        showModalContent = false
                    }
                }
                // Drives the custom present/dismiss transition inside the fullscreen cover.
                .animation(animation, value: showModalContent)

            content
        }
    }

    init(
        presentationProxy: PresentationProxy,
        animation: Animation? = .default,
        @ViewBuilder modalContent: @escaping () -> ModalContent
    ) {
        _isSheetPresented = .init(initialValue: presentationProxy.isPresented)

        self.presentationProxy = presentationProxy
        self.animation = animation
        self.modalContent = modalContent
    }
}

public extension View {
    /// Uses a ``PresentationProxy`` to present a modal view that covers as much of the screen as possible.
    ///
    /// - Parameters:
    ///   - presentation: The presentation proxy provided by a ``PresentationCoordinator``.
    ///   - animation: An optional animation for the modal transitions.
    ///   - content: A closure that returns the content of the modal view.
    func fullScreenCover(
        presentation: PresentationProxy,
        animation: Animation? = .default,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(
            FullScreenCoverModifier(
                presentationProxy: presentation,
                animation: animation,
                modalContent: content
            )
        )
    }
}
