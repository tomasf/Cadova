import Foundation
import Manifold3D

struct BinarySTLDataProvider: OutputDataProvider {
    let result: D3.BuildResult
    let options: ModelOptions
    let fileExtension = "stl"

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let acceptedSemantics = options.includedPartSemantics(for: .stl)
        let solidParts = result.elements[PartCatalog.self].mergedOutputs
            .filter { acceptedSemantics.contains($0.key.semantic) }.map(\.value)

        let allParts = [result] + solidParts
        let union = GeometryNode.boolean(allParts.map(\.node), type: .union)

        var concrete = try await context.result(for: union).concrete
        concrete = concrete.calculateNormals(channelIndex: 0)
        let meshGL = concrete.meshGL()

        let metadata = options[Metadata.self]
        let name = metadata.title ?? options[ModelName.self].name ?? "Cadova model"
        let description = metadata.description
        let author = metadata.author.map { "Author: " + $0 }
        let header = [name, description, author].compactMap { $0 }.joined(separator: "\n")
        return stlData(for: meshGL, header: header)
    }

    private func stlData(for meshGL: MeshGL, header: String) -> Data {
        let properties = meshGL.vertexProperties
        let propertyCount = meshGL.propertyCount
        let triangles = meshGL.triangles

        assert(properties.count == meshGL.vertexCount * 6) // XYZ + normals

        func double(at vertexIndex: Int, offset: Int) -> Double { properties[vertexIndex * propertyCount + offset] }
        func position(at index: Int) -> Vector3D { Vector3D(x: double(at: index, offset: 0), y: double(at: index, offset: 1), z: double(at: index, offset: 2)) }
        func normal(at index: Int) -> Vector3D { Vector3D(x: double(at: index, offset: 3), y: double(at: index, offset: 4), z: double(at: index, offset: 5)) }
        func triangleNormal(_ triangle: Manifold3D.Triangle) -> Vector3D { (normal(at: triangle.a) + normal(at: triangle.b) + normal(at: triangle.c)).normalized }

        func append(_ int: UInt32) {
            var value = int.littleEndian
            data.append(Data(bytes: &value, count: 4))
        }

        func append(_ int: UInt16) {
            var value = int.littleEndian
            data.append(Data(bytes: &value, count: 2))
        }

        func append(_ double: Double) {
            var value = Float32(double).bitPattern.littleEndian
            data.append(Data(bytes: &value, count: 4))
        }

        func append(_ vector: Vector3D) {
            append(vector.x)
            append(vector.y)
            append(vector.z)
        }

        var data = Data(capacity: 80 // 80 byte header
                        + MemoryLayout<UInt32>.size // 32-bit triangle count
                        + triangles.count * ( // For each triangle:
                            MemoryLayout<UInt16>.size // 16-bit attribute count
                            + MemoryLayout<Float32>.size * 3 * 4 // Single-precision float, three each for four vectors
                                            ))

        data.append(Data(repeating: 0, count: 80))
        let nameData = Data(header.utf8.prefix(80)).replacing("\n".utf8, with: [0])
        data.replaceSubrange(0..<nameData.count, with: nameData)

        append(UInt32(triangles.count))

        for triangle in triangles {
            append(triangleNormal(triangle))
            append(position(at: triangle.a))
            append(position(at: triangle.b))
            append(position(at: triangle.c))
            append(UInt16(0)) // attribute byte count
        }

        return data
    }
}
