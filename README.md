# FullScreenCover

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![iOS 16.4+](https://img.shields.io/badge/iOS-16.4%2B-blue)
![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-yellow)

**FullScreenCover** presents full-screen modal views in SwiftUI, building on [`.fullScreenCover`](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)) and adding what's missing:

- Use any SwiftUI transition instead of the fixed slide-up animation
- `await present()` and `await dismiss()` to safely chain sequential operations without callback workarounds

<p align="center">
  <img src="https://raw.githubusercontent.com/wiedem/fullscreen-cover/assets/custom_transition.gif" alt="Custom Transition Demo" width="280">&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/wiedem/fullscreen-cover/assets/async_coordination.gif" alt="Async Coordination Demo" width="280">
</p>

## Usage

Add `import FullScreenCover` to your source code. Wrap your view with a `PresentationCoordinator` and pass its proxy to the `fullScreenCover(presentation:animation:content:)` modifier.

### Custom Transition Animations

Use **any SwiftUI transition** combined with a transparent presentation background:

```swift
import FullScreenCover
import SwiftUI

struct DemoView: View {
    var body: some View {
        PresentationCoordinator { proxy in
            Button("Present Modal") {
                Task { try await proxy.present() }
            }
            .fullScreenCover(presentation: proxy, animation: .spring(duration: 0.5)) {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Text("Custom modal content")
                            .font(.title)

                        Button("Dismiss") {
                            Task { try await proxy.dismiss() }
                        }
                    }
                }
                .presentationBackground(Color.clear)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }
}
```

Use the [transition(_:)](https://developer.apple.com/documentation/swiftui/view/transition%28_%3A%29-5h5h0) modifier on your modal content to define your custom animation. The `animation` parameter on `fullScreenCover` controls the timing.

Setting `.presentationBackground(Color.clear)` is required for custom transitions. Without it, the native opaque background covers the transition effect.

### Async Coordination

Both `present()` and `dismiss()` are `async` and return only after the transition has completed. This makes it safe to **chain sequential operations**:

```swift
Button("Show Confirmation") {
    Task {
        // present() returns once the modal content has appeared.
        try await proxy.present()

        // Do some work while the modal is visible...
        try await performNetworkRequest()

        // dismiss() returns after the dismiss animation finishes.
        try await proxy.dismiss()

        // Safe to continue, e.g. navigate or show another modal.
        navigateToNextScreen()
    }
}
```

Both methods throw `CancellationError` if the calling task is cancelled. The transition itself continues unaffected - only the caller stops waiting.

### Presentation Phase

The proxy exposes a `phase` property of type `PresentationPhase` that tracks the current lifecycle state: `idle`, `presenting`, `presented`, or `dismissing`. Use it to adapt your UI during transitions:

```swift
PresentationCoordinator { proxy in
    Button("Present") {
        Task { try await proxy.present() }
    }
    .disabled(proxy.phase != .idle)
}
```

### Accessing the Proxy in Child Views

The `PresentationProxy` is automatically injected as an `EnvironmentObject`. Child views can access it without passing it through manually:

```swift
struct DismissButton: View {
    @EnvironmentObject private var proxy: PresentationProxy

    var body: some View {
        Button("Close") {
            Task { try await proxy.dismiss() }
        }
    }
}
```

## Installation

Add the package to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/wiedem/fullscreen-cover", .upToNextMajor(from: "2.0.0")),
```

Then include `"FullScreenCover"` as a dependency for your target:

```swift
dependencies: [
    .product(name: "FullScreenCover", package: "fullscreen-cover"),
]
```

### Requirements

- iOS 16.4+
- Swift 6.0+
- Xcode 16+

## Contributing

Contributions are welcome! Please feel free to:

- Report bugs or request features via [GitHub Issues](https://github.com/wiedem/fullscreen-cover/issues)
- Submit pull requests with improvements
- Improve documentation or add examples
- Share feedback on API design

## License

FullScreenCover is available under the MIT License. See [LICENSE.txt](LICENSE.txt) for more information.
