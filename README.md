# FullScreenCover

**FullScreenCover** is an open-source package that enables the coordinated display with custom transitions of modal views that cover as much of the screen as possible.

## Getting Started

Please note that only iOS platforms with version 15 or higher are currently supported.

To use the `FullScreenCover` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/wiedem/fullscreen-cover", .upToNextMajor(from: "1.0.0")),
```

Include `"FullScreenCover"` as a dependency for your executable target:

```swift
dependencies: [
    .product(name: "FullScreenCover", package: "fullscreen-cover"),
]
```

## Usage

Start by by adding `import FullScreenCover` to your source code.

Wrap your view using a full-screen modal with a `PresentationCoordinator` and provide the presentation proxy to the `fullScreenCover(presentation:animation:content:)` method.

```swift
import FullScreenCover
import SwiftUI

struct DemoView: View {
    var body: some View {
        PresentationCoordinator { proxy in
            VStack {
                Button("Present Modal") {
                    Task {
                        try await proxy.present()
                    }
                }
            }
            .fullScreenCover(presentation: proxy, animation: .easeIn) {
                VStack {
                    Text("Full-screen modal content")
                        .font(.title)

                    Button("Dismiss") {
                        Task {
                            // Wait for the dismiss process to complete to prevent animation and transition issues.
                            try await proxy.dismiss()
                            // Show another modal view or push a new view on the current navigation stack.
                        }
                    }
                }
                .presentationBackground(Color.clear)
                .transition(.opacity)
            }
        }
    }
}
```

The asynchronous `present()` method of the proxy returns before the modal content appears.
The exact moment corresponds to the moment the [onAppear(perform:)](https://developer.apple.com/documentation/swiftui/view/onappear%28perform%3A%29) action of the modal content is triggered.

The asynchronous method `dismiss()` of the proxy returns after the dismiss animation of the modal view is finished.
At this point, subsequent view transitions such as the display of a new modal view can be performed safely.

### Custom Transition Animations

Use the [transition(_:)](https://developer.apple.com/documentation/swiftui/view/transition%28_%3A%29-5h5h0) method to associate a transition on your modal content.

To animate the modal transitions provide an [Animation](https://developer.apple.com/documentation/swiftui/animation) instance when calling the `fullScreenCover(presentation:animation:content:)` method.
