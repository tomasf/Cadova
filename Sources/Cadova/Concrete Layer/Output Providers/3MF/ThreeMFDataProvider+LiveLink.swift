import Foundation
import Manifold3D
import LiveLink

extension ThreeMFDataProvider {
    /// Converts a resolved part's evaluated geometry into a LiveLink wire message part,
    /// deduplicating materials the same way `makeModel`'s `addMaterial` does for the 3MF path,
    /// just against LiveLink's own flat material palette instead of a `ColorGroup`.
    static func liveLinkPart(_ resolved: ResolvedPart) -> LiveLinkMessage.Part {
        let meshGL = resolved.manifold.meshGL()
        let vertices = meshGL.vertices
        let triangles = meshGL.triangles
        let triangleOIDs = TriangleOIDMapping(indexSets: meshGL.originalIDs)

        var materialIndices: [Material: Int32] = [:]
        var materials: [LiveLinkMessage.MaterialEntry] = []

        func index(for material: Material) -> Int32 {
            if let existing = materialIndices[material] { return existing }
            let newIndex = Int32(materials.count)
            materials.append(LiveLinkMessage.MaterialEntry(
                color: material.baseColor.liveLinkRGBA,
                name: material.name,
                metallicness: material.physicalProperties?.metallicness,
                roughness: material.physicalProperties?.roughness
            ))
            materialIndices[material] = newIndex
            return newIndex
        }

        let defaultMaterialIndex = resolved.part.defaultMaterial.map(index)

        var vertexFlat: [Double] = []
        vertexFlat.reserveCapacity(vertices.count * 3)
        for vertex in vertices {
            vertexFlat.append(vertex.x)
            vertexFlat.append(vertex.y)
            vertexFlat.append(vertex.z)
        }

        var triangleFlat: [UInt32] = []
        var triangleMaterialIndices: [Int32] = []
        triangleFlat.reserveCapacity(triangles.count * 3)
        triangleMaterialIndices.reserveCapacity(triangles.count)

        for (triangleIndex, triangle) in triangles.enumerated() {
            triangleFlat.append(UInt32(triangle.a))
            triangleFlat.append(UInt32(triangle.b))
            triangleFlat.append(UInt32(triangle.c))

            if let originalID = triangleOIDs.originalID(for: triangleIndex), let material = resolved.materials[originalID] {
                triangleMaterialIndices.append(index(for: material))
            } else {
                triangleMaterialIndices.append(-1)
            }
        }

        return LiveLinkMessage.Part(
            name: resolved.part.name,
            isPrintable: resolved.part.semantic == .solid,
            transform: nil,
            vertices: vertexFlat,
            triangles: triangleFlat,
            triangleMaterialIndices: triangleMaterialIndices,
            defaultMaterialIndex: defaultMaterialIndex,
            materials: materials
        )
    }
}

private extension Color {
    var liveLinkRGBA: LiveLinkMessage.RGBA {
        .init(
            red: UInt8(round(red * 255.0)),
            green: UInt8(round(green * 255.0)),
            blue: UInt8(round(blue * 255.0)),
            alpha: UInt8(round(alpha * 255.0))
        )
    }
}
