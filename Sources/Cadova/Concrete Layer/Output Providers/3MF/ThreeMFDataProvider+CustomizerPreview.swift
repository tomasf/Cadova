import Foundation

extension ThreeMFDataProvider {
    /// The model's parts in the web customizer's preview format, which its page reads straight into
    /// typed arrays: the meshes LiveLink sends, without the XML and compression of a 3MF file. The page
    /// and the model are always built together, so the format has no header or version of its own.
    ///
    /// Everything is little-endian, and arrays start at multiples of four bytes (eight for vertex
    /// coordinates), so that the page can view it in place:
    ///
    /// ```
    /// part count: u32
    /// For each part:
    ///   id, name, semantic: string (u32 byte count, UTF-8, zero-padded to a multiple of four)
    ///   vertex count: u32, zero padding to 8-byte alignment, positions: f64 × 3 × vertex count
    ///   triangle count: u32, vertex indices: u32 × 3 × triangle count,
    ///     material indices: i32 × triangle count (-1 for none)
    ///   default material index: i32 (-1 for none)
    ///   material count: u32, for each: sRGB red, green, blue, alpha: u8 × 4,
    ///     metallicness, roughness: f64 (NaN for a material without physical properties)
    /// ```
    func customizerPreview(context: EvaluationContext) async throws -> Data? {
        var writer = PreviewWriter()
        let parts = try await meshParts(context: context)
        writer.append(UInt32(parts.count))
        for part in parts {
            writer.append(part.id)
            writer.append(part.part.name)
            writer.append(part.part.semantic.rawValue)

            writer.append(UInt32(part.vertices.count))
            // Keep the original precision until the browser has classified edges.
            // Rounding thin triangles to Float first can turn smooth faces into creases.
            writer.align(to: 8)
            writer.append(part.vertices.flatMap { [$0.x, $0.y, $0.z] })

            writer.append(UInt32(part.triangleMaterialIndices.count))
            writer.append(part.triangles)
            writer.append(part.triangleMaterialIndices)
            writer.append(part.defaultMaterialIndex ?? -1)

            writer.append(UInt32(part.materials.count))
            for material in part.materials {
                let color = material.baseColor
                writer.append(contentsOf: [color.red, color.green, color.blue, color.alpha].map { UInt8(round($0 * 255.0)) })
                writer.append(material.physicalProperties?.metallicness ?? .nan)
                writer.append(material.physicalProperties?.roughness ?? .nan)
            }
        }
        return Data(writer.bytes)
    }
}

/// Collects the bytes of a customizer preview.
private struct PreviewWriter {
    private(set) var bytes: [UInt8] = []

    mutating func append(contentsOf newBytes: [UInt8]) {
        bytes.append(contentsOf: newBytes)
    }

    mutating func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }

    mutating func append(_ value: Double) {
        append(value.bitPattern)
    }

    mutating func append<T: FixedWidthInteger>(_ values: [T]) {
        values.map(\.littleEndian).withUnsafeBytes { bytes.append(contentsOf: $0) }
    }

    mutating func append(_ values: [Double]) {
        append(values.map(\.bitPattern))
    }

    mutating func align(to alignment: Int) {
        while bytes.count % alignment != 0 {
            bytes.append(0)
        }
    }

    /// A string, zero-padded so that whatever follows it stays aligned to four bytes.
    mutating func append(_ string: String) {
        let utf8 = Array(string.utf8)
        append(UInt32(utf8.count))
        bytes.append(contentsOf: utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: (4 - utf8.count % 4) % 4))
    }
}
