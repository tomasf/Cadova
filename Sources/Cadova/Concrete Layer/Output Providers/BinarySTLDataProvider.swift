import Foundation
import Manifold3D

struct BinarySTLDataProvider: OutputDataProvider {
    let result: BuildResult<D3>
    let options: ModelOptions
    let fileExtension = "stl"

    /// A binary STL starts with a fixed 80 bytes of free-form text, followed by a 32-bit triangle
    /// count. Each triangle is then a 50-byte record: four vectors of three single-precision
    /// floats (the normal and three corners), plus a 16-bit attribute byte count.
    private static let headerLength = 80
    private static let triangleRecordLength = MemoryLayout<Float32>.size * 3 * 4 + MemoryLayout<UInt16>.size

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let acceptedSemantics = options.includedPartSemantics(for: .stl)
        let solidParts = result.elements[PartCatalog.self].mergedOutputs
            .filter { acceptedSemantics.contains($0.key.semantic) }.map(\.value)

        let allParts = [result] + solidParts
        let union = GeometryNode.boolean(allParts.map(\.node), type: .union)

        let concrete = try await context.result(for: union).concrete
        let meshGL = concrete.meshGL()

        let metadata = options[Metadata.self]
        let name = metadata.title ?? options[ModelName.self].name ?? "Cadova model"
        let description = metadata.description
        let author = metadata.author.map { "Author: " + $0 }
        let header = [name, description, author].compactMap { $0 }.joined(separator: "\n")
        return stlData(for: meshGL, header: header)
    }

    private func stlData(for meshGL: MeshGL, header: String) -> Data {
        let vertices = meshGL.vertices
        let triangles = meshGL.triangles

        func triangleNormal(_ triangle: Manifold3D.Triangle) -> Vector3D {
            ((vertices[triangle.b] - vertices[triangle.a]) × (vertices[triangle.c] - vertices[triangle.a])).normalized
        }

        let headerBytes = Self.headerBytes(for: header)
        let size = Self.headerLength
            + MemoryLayout<UInt32>.size
            + triangles.count * Self.triangleRecordLength

        // The whole file is sized up front and filled through a moving cursor. Appending scalar by
        // scalar instead boxes each of the thirteen values per triangle in its own reference
        // counted Data, which for a large mesh costs more than generating the mesh did.
        var data = Data(count: size)

        data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0

            // `storeBytes(of:toByteOffset:as:)` wants an offset aligned for the type it writes,
            // and STL's 50-byte record deliberately leaves floats on two-byte offsets.
            // `copyMemory` carries no alignment requirement.
            func append<T: FixedWidthInteger>(_ value: T) {
                withUnsafeBytes(of: value.littleEndian) {
                    base.advanced(by: offset).copyMemory(from: $0.baseAddress!, byteCount: MemoryLayout<T>.size)
                }
                offset += MemoryLayout<T>.size
            }

            func append(_ double: Double) {
                append(Float32(double).bitPattern)
            }

            func append(_ vector: Vector3D) {
                append(vector.x)
                append(vector.y)
                append(vector.z)
            }

            headerBytes.withUnsafeBytes { bytes in
                if let start = bytes.baseAddress {
                    base.copyMemory(from: start, byteCount: bytes.count)
                }
            }
            offset = Self.headerLength // Whatever the header didn't fill stays zeroed

            append(UInt32(triangles.count))

            for triangle in triangles {
                append(triangleNormal(triangle))
                append(vertices[triangle.a])
                append(vertices[triangle.b])
                append(vertices[triangle.c])
                append(UInt16(0)) // Attribute byte count
            }
        }

        return data
    }

    /// The text of the 80-byte prologue, cut to fit.
    ///
    /// The cut falls on a character boundary: truncating the UTF-8 bytes directly can land in the
    /// middle of a multi-byte sequence and leave a header no reader can decode. Newlines separate
    /// the metadata fields, which the fixed-size header has no room to keep apart, so they become
    /// nulls.
    private static func headerBytes(for header: String) -> Data {
        var bytes = Data(capacity: headerLength)
        for character in header {
            guard bytes.count + character.utf8.count <= headerLength else { break }
            bytes.append(contentsOf: character.utf8.lazy.map { $0 == UInt8(ascii: "\n") ? 0 : $0 })
        }
        return bytes
    }
}
