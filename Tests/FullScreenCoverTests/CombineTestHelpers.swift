import Combine
import Foundation

@MainActor
final class CancellableHolder: Sendable {
    var cancellable: AnyCancellable?

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

@MainActor
func collectValues<P: Publisher>(
    from publisher: P,
    max: Int,
    timeout: Duration = .seconds(3)
) -> Task<[P.Output], any Error> where P.Failure == Never, P.Output: Sendable {
    let holder = CancellableHolder()

    return Task { @MainActor in
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                holder.cancellable = publisher
                    .prefix(max)
                    .setFailureType(to: (any Error).self)
                    .timeout(
                        .seconds(Int(timeout.components.seconds)),
                        scheduler: RunLoop.main,
                        customError: { CancellationError() }
                    )
                    .collect()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { continuation.resume(returning: $0) }
                    )
            }
        } onCancel: {
            Task { @MainActor in
                holder.cancel()
            }
        }
    }
}
