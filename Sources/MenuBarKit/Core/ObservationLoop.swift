import Observation

/// Re-runs `body` whenever any observable property it read changes, until cancelled.
/// Bridges @Observable state into AppKit objects (e.g. status item visibility).
@MainActor
final class ObservationLoop {
    private let body: @MainActor () -> Void
    private var isCancelled = false

    init(_ body: @escaping @MainActor () -> Void) {
        self.body = body
        run()
    }

    func cancel() {
        isCancelled = true
    }

    private func run() {
        guard !isCancelled else { return }
        withObservationTracking {
            body()
        } onChange: { [weak self] in
            Task { @MainActor in self?.run() }
        }
    }
}
