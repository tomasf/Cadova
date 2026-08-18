import Foundation

/// Wire framing for a single `LiveLinkMessage`: a fixed 16-byte header (magic, protocol
/// version, payload length) followed by the encoded payload. Used by both `LiveLinkClient`
/// and `LiveLinkServer`, which speak over a stream-oriented Unix domain socket connection.
public enum LiveLinkFraming {
    static let magic: UInt32 = 0x4c4c_494e // "LLIN"
    static let protocolVersion: UInt32 = 1
    public static let headerSize = 16

    public enum FramingError: Error {
        case invalidMagic
        case unsupportedVersion(UInt32)
    }

    public static func makeFrame(for message: LiveLinkMessage) throws -> Data {
        let payload = try PropertyListEncoder().encode(message)
        var frame = Data(capacity: headerSize + payload.count)
        frame.append(bigEndianBytes(magic))
        frame.append(bigEndianBytes(protocolVersion))
        frame.append(bigEndianBytes(UInt64(payload.count)))
        frame.append(payload)
        return frame
    }

    /// Parses a `headerSize`-byte header, returning the length of the payload that follows.
    public static func parseHeader(_ data: Data) throws -> Int {
        let magicValue = readUInt32(data, at: 0)
        guard magicValue == magic else { throw FramingError.invalidMagic }

        let versionValue = readUInt32(data, at: 4)
        guard versionValue == protocolVersion else { throw FramingError.unsupportedVersion(versionValue) }

        return Int(readUInt64(data, at: 8))
    }

    public static func decodeMessage(_ data: Data) throws -> LiveLinkMessage {
        try PropertyListDecoder().decode(LiveLinkMessage.self, from: data)
    }

    private static func bigEndianBytes(_ value: UInt32) -> Data {
        Data((0..<4).reversed().map { UInt8((value >> ($0 * 8)) & 0xff) })
    }

    private static func bigEndianBytes(_ value: UInt64) -> Data {
        Data((0..<8).reversed().map { UInt8((value >> ($0 * 8)) & 0xff) })
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        return data[start ..< start + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        let start = data.startIndex + offset
        return data[start ..< start + 8].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
