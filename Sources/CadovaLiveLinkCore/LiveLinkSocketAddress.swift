import Foundation

#if canImport(Darwin)
import Darwin

/// Shared `sockaddr_un` construction for both `LiveLinkClient` (connecting) and `LiveLinkServer`
/// (binding), which otherwise have no reason to depend on each other.
public enum LiveLinkSocketAddress {
    public struct PathTooLong: Error {}

    /// Copies `path`'s UTF-8 bytes into `sun_path`, which is a fixed-size C array bridged into
    /// Swift as a tuple — `withUnsafeMutableBytes(of:)` is the standard way to write into one.
    public static func setPath(_ path: String, on addr: inout sockaddr_un) throws {
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
#endif
