import SwiftUI

struct FullScreenCoverModifier<ModalContent>: ViewModifier where ModalContent: View {
    @State private var isSheetPresented: Bool
    @State private var showModalContent = false
    @ObservedObject private var presentationProxy: PresentationProxy

    @ViewBuilder private let modalContent: () -> ModalContent

    private let animation: Animation?
    private var onWillPresent: (() -> Void)?
    private var onDidDismiss: (() -> Void)?

    func body(content: Content) -> some View {
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
                                    presentationProxy.onWillPresent()
                                }
                                .onDisappear {
                                    guard isSheetPresented else { return }
                                    isSheetPresented = false
                                }
                        }
                    }
                    .task {
                        guard showModalContent == false else { return }
                        // The binding value may have changed while the view was in the display process.
                        // If this is the case, immediately set the presentation state, because the onChange handler won't be triggered again.
                        guard presentationProxy.isPresented else {
                            isSheetPresented = false
                            return
                        }

                        showModalContent = true
                    }
                }
                .transaction { transaction in
                    // Disable the standard SwiftUI animation for fullscreen modal presentations.
                    transaction.disablesAnimations = true
                }
                .onChange(of: presentationProxy.isPresented) { newValue in
                    if newValue {
                        // Immediately show the modal content wrapper, the delayed setting of showModalContent will trigger the actual animation of the model content transition.
                        isSheetPresented = true
                    } else {
                        // Check if the content is marked as being visible. If this is not the case then the binding changed before the modal content did have a chance to become visible.
                        guard showModalContent else {
                            isSheetPresented = false
                            return
                        }

                        // Don't immediately change the state of the modal wrapper but wait for the modal content to disappear.
                        showModalContent = false
                    }
                }
                .animation(animation, value: showModalContent)

            content
        }
    }

    init(
        presentationProxy: PresentationProxy,
        animation: Animation? = nil,
        @ViewBuilder modalContent: @escaping () -> ModalContent
    ) {
        _isSheetPresented = .init(initialValue: presentationProxy.isPresented)

        self.presentationProxy = presentationProxy
        self.animation = animation
        self.modalContent = modalContent

        onWillPresent = { [weak presentationProxy] in
            presentationProxy?.onWillPresent()
        }
        onDidDismiss = { [weak presentationProxy] in
            presentationProxy?.onDidDismiss()
        }
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
        animation: Animation? = nil,
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
