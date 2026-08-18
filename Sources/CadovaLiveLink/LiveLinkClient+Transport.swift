import Foundation

#if os(macOS)
import Network

extension LiveLinkClient {
    struct TimedOut: Error {}

    /// How long to wait for the whole push to go through before giving up. Generous relative to
    /// how fast a local socket transfer "should" be, because it also has to cover a real payload
    /// (megabytes of mesh data) being sent in chunks, not just connection setup.
    private static let timeout: Duration = .seconds(3)

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
                // A throwing task group can't return until every child has actually finished —
                // merely marking `sendFrame`'s task cancelled doesn't do that, since it's blocked on
                // an NWConnection state callback, not a cancellation-aware suspension point. Without
                // this, a connection that never reaches .ready deadlocks here forever instead of
                // timing out, which — since Model.build() awaits this directly — silently hangs
                // every build until the process happens to exit.
                connection.cancel()
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

    /// A single `connection.send(content:)` call carrying the whole multi-megabyte frame in one
    /// `Data` blob is unreliable in practice — it can sit forever without its completion handler
    /// ever firing, with nothing ever reaching the peer. Sending in bounded chunks (mirroring the
    /// chunked reads on the receiving side) avoids that.
    private static let chunkSize = 1 << 18 // 256 KB

    private static func sendFrame(_ frame: Data, over connection: NWConnection, queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = SingleResumeBox(continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    sendChunk(frame, from: frame.startIndex, over: connection, box: box)
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

    private static func sendChunk(_ frame: Data, from offset: Data.Index, over connection: NWConnection, box: SingleResumeBox) {
        guard offset < frame.endIndex else {
            box.resume(.success(()))
            return
        }
        let end = frame.index(offset, offsetBy: chunkSize, limitedBy: frame.endIndex) ?? frame.endIndex
        let chunk = frame.subdata(in: offset..<end)
        connection.send(content: chunk, completion: .contentProcessed { error in
            if let error {
                box.resume(.failure(error))
            } else {
                sendChunk(frame, from: end, over: connection, box: box)
            }
        })
    }
}

#else

extension LiveLinkClient {
    static func send(_ message: LiveLinkMessage) async throws {}
}

#endif
