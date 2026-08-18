import Foundation

#if os(macOS)
import Network

extension LiveLinkClient {
    struct TimedOut: Error {}

    /// How long to wait for the push to be accepted before giving up. Bounds the worst-case
    /// added latency when the socket file exists but nothing is actually accepting connections
    /// on it (e.g. a stale file left behind by a crashed listener).
    private static let timeout: Duration = .milliseconds(250)

    static func send(_ message: LiveLinkMessage) async throws {
        let frame = try LiveLinkFraming.makeFrame(for: message)
        let queue = DispatchQueue(label: "se.tomasf.CadovaLiveLink.client")
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(to: .unix(path: LiveLinkEndpoint.socketPath), using: parameters)
        defer { connection.cancel() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await sendFrame(frame, over: connection, queue: queue)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw TimedOut()
            }
            try await group.next()
            group.cancelAll()
        }
    }

    /// Resumes a `CheckedContinuation` exactly once, ignoring any further calls. `NWConnection`
    /// can report readiness, failure, and cancellation on the same queue in ways that would
    /// otherwise risk resuming the continuation twice (a runtime crash).
    private final class SingleResumeBox: @unchecked Sendable {
        private let lock = NSLock()
        private var didResume = false
        private let continuation: CheckedContinuation<Void, Error>

        init(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<Void, Error>) {
            lock.lock()
            let alreadyResumed = didResume
            didResume = true
            lock.unlock()
            guard !alreadyResumed else { return }
            continuation.resume(with: result)
        }
    }

    private static func sendFrame(_ frame: Data, over connection: NWConnection, queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = SingleResumeBox(continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: frame, completion: .contentProcessed { error in
                        if let error {
                            box.resume(.failure(error))
                        } else {
                            box.resume(.success(()))
                        }
                    })
                case .failed(let error):
                    box.resume(.failure(error))
                case .cancelled:
                    box.resume(.failure(CancellationError()))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }
}

#else

extension LiveLinkClient {
    static func send(_ message: LiveLinkMessage) async throws {}
}

#endif
