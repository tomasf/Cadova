import Foundation

extension ThreeMFDataProvider {
    /// The model's parts in the web customizer's preview format, which its page reads straight into
    /// typed arrays: the meshes LiveLink sends, without the XML and compression of a 3MF file.
    ///
    /// Everything is little-endian, and every array starts at a multiple of four bytes, so that the
    /// page can view it in place:
    ///
    /// ```
    /// "CDVP", version: u32 (1), part count: u32
    /// For each part:
    ///   id, name, semantic: string (u32 byte count, UTF-8, zero-padded to a multiple of four)
    ///   vertex count: u32, positions: f32 × 3 × vertex count
    ///   triangle count: u32, vertex indices: u32 × 3 × triangle count,
    ///     material indices: i32 × triangle count (-1 for none)
    ///   default material index: i32 (-1 for none)
    ///   material count: u32, for each: sRGB red, green, blue, alpha: u8 × 4,
    ///     metallicness, roughness: f64 (NaN for a material without physical properties)
    /// ```
    func customizerPreview(context: EvaluationContext) async throws -> Data? {
        var writer = PreviewWriter()
        writer.append(contentsOf: Array("CDVP".utf8))
        writer.append(UInt32(1))

        let parts = try await meshParts(context: context)
        writer.append(UInt32(parts.count))
        for part in parts {
            writer.append(part.id)
            writer.append(part.part.name)
            writer.append(part.part.semantic.rawValue)

            writer.append(UInt32(part.vertices.count))
            writer.append(part.vertices.flatMap { [Float($0.x), Float($0.y), Float($0.z)] })

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

    mutating func append(_ values: [Float]) {
        append(values.map(\.bitPattern))
    }

    /// A string, zero-padded so that whatever follows it stays aligned to four bytes.
    mutating func append(_ string: String) {
        let utf8 = Array(string.utf8)
        append(UInt32(utf8.count))
        bytes.append(contentsOf: utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: (4 - utf8.count % 4) % 4))
    }
}
