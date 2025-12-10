import Foundation

/// Detected format of a 3D model file.
internal enum ModelFileFormat {
    case threeMF
    case stlBinary
    case stlASCII

    /// Detects the format of a model file by examining its contents.
    ///
    /// - Parameter url: The file URL to examine.
    /// - Returns: The detected format, or `nil` if the format is not recognized.
    ///
    static func detect(at url: URL) throws -> ModelFileFormat? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        guard let header = try handle.read(upToCount: 80) else {
            return nil
        }

        return detectFromHeader(header)
    }

    /// Detects the format of a model file by examining its contents.
    ///
    /// - Parameter data: The file data to examine.
    /// - Returns: The detected format, or `nil` if the format is not recognized.
    ///
    static func detect(from data: Data) -> ModelFileFormat? {
        detectFromHeader(data.prefix(80))
    }

    private static func detectFromHeader(_ header: some Collection<UInt8>) -> ModelFileFormat? {
        guard header.count >= 4 else { return nil }

        let headerArray = Array(header.prefix(80))

        // Check for ZIP signature (3MF files are ZIP archives)
        // ZIP files start with PK\x03\x04
        if headerArray.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            return .threeMF
        }

        // Check for ASCII STL: starts with "solid " followed by a name
        // Note: Some binary STL files may also start with "solid" in the header,
        // so we need additional heuristics
        if let headerString = String(bytes: headerArray, encoding: .ascii),
           headerString.lowercased().hasPrefix("solid ") {
            // Could be ASCII STL, but binary STL headers can also start with "solid"
            // ASCII STL will have "facet normal" appearing after the solid line
            // We'll mark it as potentially ASCII and verify later with more data
            return .stlASCII
        }

        // Default to binary STL if we have at least 80 bytes
        // Binary STL has an 80-byte header followed by a 4-byte little-endian triangle count
        if headerArray.count >= 80 {
            return .stlBinary
        }

        return nil
    }
}
