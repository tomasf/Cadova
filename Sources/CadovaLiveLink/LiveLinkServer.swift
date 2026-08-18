import Foundation

#if os(macOS)
import Network

/// Listens for `LiveLinkMessage` pushes at the well-known LiveLink socket. Intended for a
/// long-running consumer such as Cadova Viewer: create one instance, call `start()` once
/// (typically at app launch) and `stop()` on shutdown.
///
/// Only one `LiveLinkServer` can be bound at a time system-wide, since a Unix domain socket
/// has exactly one listener per path — if another process already owns the socket, `start()`
/// throws and this instance simply never receives anything, which callers should treat as a
/// non-fatal degradation (e.g. a second app instance still works, just without the fast path).
public final class LiveLinkServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "se.tomasf.CadovaLiveLink.server")
    private let onMessage: @Sendable (LiveLinkMessage) -> Void
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    public init(onMessage: @escaping @Sendable (LiveLinkMessage) -> Void) {
        self.onMessage = onMessage
    }

    public func start() throws {
        let path = LiveLinkEndpoint.socketPath
        try? FileManager.default.removeItem(atPath: path)

        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.requiredLocalEndpoint = .unix(path: path)
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            for connection in connections.values { connection.cancel() }
            connections.removeAll()
        }
        try? FileManager.default.removeItem(atPath: LiveLinkEndpoint.socketPath)
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        queue.async { self.connections[id] = connection }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                guard let self else { return }
                queue.async { self.connections.removeValue(forKey: id) }
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveHeader(on: connection)
    }

    private func receiveHeader(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: LiveLinkFraming.headerSize, maximumLength: LiveLinkFraming.headerSize) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            guard let data, data.count == LiveLinkFraming.headerSize else {
                connection.cancel()
                return
            }
            do {
                let length = try LiveLinkFraming.parseHeader(data)
                self.receivePayload(on: connection, length: length)
            } catch {
                connection.cancel()
            }
        }
    }

    private func receivePayload(on connection: NWConnection, length: Int, accumulated: Data = Data()) {
        let remaining = length - accumulated.count
        guard remaining > 0 else {
            if let message = try? LiveLinkFraming.decodeMessage(accumulated) {
                onMessage(message)
            }
            connection.cancel()
            return
        }

        let chunkSize = min(remaining, 1 << 20)
        connection.receive(minimumIncompleteLength: 1, maximumLength: chunkSize) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var accumulated = accumulated
            if let data { accumulated.append(data) }

            if error != nil || (isComplete && accumulated.count < length) {
                connection.cancel()
                return
            }
            self.receivePayload(on: connection, length: length, accumulated: accumulated)
        }
    }
}

#else

/// LiveLink is macOS-only; on other platforms this type exists so cross-platform code can
/// reference it unconditionally, but `start()` always throws and no messages are ever received.
public final class LiveLinkServer: @unchecked Sendable {
    struct UnsupportedPlatform: Error {}

    public init(onMessage: @escaping @Sendable (LiveLinkMessage) -> Void) {}
    public func start() throws { throw UnsupportedPlatform() }
    public func stop() {}
}

#endif
