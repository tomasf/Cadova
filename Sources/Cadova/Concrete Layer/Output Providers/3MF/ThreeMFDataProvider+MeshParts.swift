import Foundation
import Manifold3D

extension ThreeMFDataProvider {
    /// A resolved part as plain arrays, for readers that take meshes directly instead of a 3MF file:
    /// LiveLink and the web customizer's preview. Materials are deduplicated into a flat palette that
    /// triangles refer to by index, the way `makeModel`'s `addMaterial` deduplicates them into color
    /// groups for the 3MF file.
    struct MeshPart {
        /// The part's entry from `fileIdentifiers(for:)`, matching what ends up in the 3MF file.
        let id: String
        let part: Part
        let vertices: [Vector3D]
        /// Three vertex indices for each triangle.
        let triangles: [UInt32]
        /// An index into `materials` for each triangle, or -1 for one without a material of its own.
        let triangleMaterialIndices: [Int32]
        let defaultMaterialIndex: Int32?
        let materials: [Material]

        init(id: String, _ resolved: ResolvedPart) {
            let meshGL = resolved.manifold.meshGL()
            let manifoldTriangles = meshGL.triangles
            let triangleOIDs = TriangleOIDMapping(indexSets: meshGL.originalIDs)

            var materialIndices: [Material: Int32] = [:]
            var materials: [Material] = []
            func index(for material: Material) -> Int32 {
                if let existing = materialIndices[material] { return existing }
                let newIndex = Int32(materials.count)
                materials.append(material)
                materialIndices[material] = newIndex
                return newIndex
            }

            defaultMaterialIndex = resolved.part.defaultMaterial.map(index)

            var triangles: [UInt32] = []
            var triangleMaterialIndices: [Int32] = []
            triangles.reserveCapacity(manifoldTriangles.count * 3)
            triangleMaterialIndices.reserveCapacity(manifoldTriangles.count)

            for (triangleIndex, triangle) in manifoldTriangles.enumerated() {
                triangles.append(UInt32(triangle.a))
                triangles.append(UInt32(triangle.b))
                triangles.append(UInt32(triangle.c))

                if let originalID = triangleOIDs.originalID(for: triangleIndex), let material = resolved.materials[originalID] {
                    triangleMaterialIndices.append(index(for: material))
                } else {
                    triangleMaterialIndices.append(-1)
                }
            }

            self.id = id
            self.part = resolved.part
            self.vertices = meshGL.vertices
            self.triangles = triangles
            self.triangleMaterialIndices = triangleMaterialIndices
            self.materials = materials
        }
    }

    /// Every included part as a mesh, in the order the 3MF file lists them.
    func meshParts(context: EvaluationContext) async throws -> [MeshPart] {
        let parts = try await resolvedParts(context: context)
        return zip(Self.fileIdentifiers(for: parts), parts)
            .sorted { Self.fileOrder($0.0, $1.0) }
            .map { MeshPart(id: $0, $1) }
    }
}
