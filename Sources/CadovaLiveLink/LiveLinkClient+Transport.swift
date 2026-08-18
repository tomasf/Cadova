import Foundation

#if os(macOS)
import Darwin

/// Raw POSIX socket transport, deliberately not `Network.framework`: `NWConnection` has no
/// protocol-options class for a plain local stream, so it uses `NWProtocolTCP.Options()` even over
/// a Unix domain socket. At some point in a connection's lifecycle it queries TCP-specific stats via
/// `getsockopt(TCP_INFO)` for its own internal telemetry, which fails on a socket that was never
/// really TCP and logs that failure — loudly, and to the exact console Cadova users are watching
/// while their model builds. A raw socket never goes near that code path.
extension LiveLinkClient {
    struct ConnectFailed: Error { let errno: Int32 }
    struct WriteFailed: Error { let errno: Int32 }
    struct PathTooLong: Error {}

    /// Bounds a write that never completes (e.g. a listener that accepted but isn't reading),
    /// enforced by the kernel via `SO_SNDTIMEO` rather than a client-side race, since there's no
    /// way to safely interrupt a blocking POSIX `write()` from another thread.
    private static let sendTimeout: TimeInterval = 3

    static func send(_ message: LiveLinkMessage) async throws {
        let frame = try LiveLinkFraming.makeFrame(for: message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try writeBlocking(frame)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func writeBlocking(_ frame: Data) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ConnectFailed(errno: errno) }
        defer { close(fd) }

        var sendTimeoutValue = timeval(tv_sec: Int(sendTimeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeoutValue, socklen_t(MemoryLayout<timeval>.size))

        let path = LiveLinkEndpoint.socketPath
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        try Self.setPath(path, on: &addr)

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { throw ConnectFailed(errno: errno) }

        try frame.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let n = write(fd, base + offset, raw.count - offset)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw WriteFailed(errno: errno)
                }
                if n == 0 { break }
                offset += n
            }
        }
    }

    /// Copies `path`'s UTF-8 bytes into `sun_path`, which is a fixed-size C array bridged into
    /// Swift as a tuple — `withUnsafeMutableBytes(of:)` is the standard way to write into one.
    static func setPath(_ path: String, on addr: inout sockaddr_un) throws {
        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count < capacity else { throw PathTooLong() }

        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            for (index, byte) in pathBytes.enumerated() {
                buffer[index] = byte
            }
            buffer[pathBytes.count] = 0
        }
    }
}

#else

extension LiveLinkClient {
    static func send(_ message: LiveLinkMessage) async throws {}
}

#endif
