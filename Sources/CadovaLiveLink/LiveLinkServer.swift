import Foundation

#if os(macOS)
import Darwin

/// Listens for `LiveLinkMessage` pushes at the well-known LiveLink socket. Intended for a
/// long-running consumer such as Cadova Viewer: create one instance, call `start()` once
/// (typically at app launch) and `stop()` on shutdown.
///
/// Only one `LiveLinkServer` can be bound at a time system-wide, since a Unix domain socket
/// has exactly one listener per path — if another process already owns the socket, `start()`
/// throws and this instance simply never receives anything, which callers should treat as a
/// non-fatal degradation (e.g. a second app instance still works, just without the fast path).
///
/// Built on raw POSIX sockets rather than `Network.framework` — see the comment on
/// `LiveLinkClient`'s transport for why.
public final class LiveLinkServer: @unchecked Sendable {
    struct BindFailed: Error { let errno: Int32 }

    private let queue = DispatchQueue(label: "se.tomasf.CadovaLiveLink.server")
    private let onMessage: @Sendable (LiveLinkMessage) -> Void
    private var listenerFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: ConnectionState] = [:]

    private final class ConnectionState {
        var buffer = Data()
        var readSource: DispatchSourceRead?
    }

    public init(onMessage: @escaping @Sendable (LiveLinkMessage) -> Void) {
        self.onMessage = onMessage
    }

    public func start() throws {
        let path = LiveLinkEndpoint.socketPath
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw BindFailed(errno: errno) }
        // acceptNewConnections() below loops calling accept() until it returns EWOULDBLOCK, to
        // drain every currently-pending connection in one DispatchSource firing — which requires
        // the listening socket to actually be non-blocking. Without this, accept() blocks forever
        // once the pending backlog is empty, freezing this serial queue (and with it every
        // already-accepted connection's reads, since they share the same queue) permanently.
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        do {
            try LiveLinkClient.setPath(path, on: &addr)
        } catch {
            close(fd)
            throw error
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw BindFailed(errno: errno)
        }
        guard listen(fd, 8) == 0 else {
            close(fd)
            throw BindFailed(errno: errno)
        }

        listenerFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptNewConnections()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        acceptSource = source
    }

    public func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            listenerFD = -1
            for (fd, state) in connections {
                state.readSource?.cancel()
                close(fd)
            }
            connections.removeAll()
        }
        try? FileManager.default.removeItem(atPath: LiveLinkEndpoint.socketPath)
    }

    private func acceptNewConnections() {
        while true {
            let clientFD = accept(listenerFD, nil, nil)
            guard clientFD >= 0 else { break }
            _ = fcntl(clientFD, F_SETFL, O_NONBLOCK)

            let state = ConnectionState()
            connections[clientFD] = state
            let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
            source.setEventHandler { [weak self] in
                self?.readAvailable(from: clientFD)
            }
            source.setCancelHandler { [weak self] in
                close(clientFD)
                self?.connections.removeValue(forKey: clientFD)
            }
            state.readSource = source
            source.resume()
        }
    }

    private func readAvailable(from fd: Int32) {
        guard let state = connections[fd] else { return }

        var chunk = [UInt8](repeating: 0, count: 1 << 20)
        let n = chunk.withUnsafeMutableBytes { raw in
            read(fd, raw.baseAddress, raw.count)
        }
        if n < 0 {
            // EAGAIN/EWOULDBLOCK on a non-blocking socket just means "nothing to read yet, despite
            // the read source firing" — not an error, and not the peer closing the connection.
            if errno == EAGAIN || errno == EWOULDBLOCK { return }
            state.readSource?.cancel()
            return
        }
        guard n > 0 else {
            state.readSource?.cancel()
            return
        }

        state.buffer.append(contentsOf: chunk[0..<n])
        processBuffer(state)
    }

    /// One message per connection — the client opens a fresh connection for every push — so once
    /// a full frame has been assembled and handed to `onMessage`, the connection is done.
    private func processBuffer(_ state: ConnectionState) {
        guard state.buffer.count >= LiveLinkFraming.headerSize else { return }

        let header = state.buffer.subdata(in: state.buffer.startIndex..<(state.buffer.startIndex + LiveLinkFraming.headerSize))
        guard let payloadLength = try? LiveLinkFraming.parseHeader(header) else {
            state.readSource?.cancel()
            return
        }

        let totalLength = LiveLinkFraming.headerSize + payloadLength
        guard state.buffer.count >= totalLength else { return }

        let payloadStart = state.buffer.startIndex + LiveLinkFraming.headerSize
        let payload = state.buffer.subdata(in: payloadStart..<(state.buffer.startIndex + totalLength))
        if let message = try? LiveLinkFraming.decodeMessage(payload) {
            onMessage(message)
        }
        state.readSource?.cancel()
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
