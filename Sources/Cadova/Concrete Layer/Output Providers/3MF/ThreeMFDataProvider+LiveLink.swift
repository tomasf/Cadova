import Foundation
import Manifold3D
#if canImport(CadovaLiveLinkClient)
internal import CadovaLiveLinkCore

extension ThreeMFDataProvider {
    /// Converts a part's mesh into a LiveLink wire message part.
    static func liveLinkPart(_ meshPart: MeshPart) -> LiveLinkMessage.Part {
        var vertexFlat: [Double] = []
        vertexFlat.reserveCapacity(meshPart.vertices.count * 3)
        for vertex in meshPart.vertices {
            vertexFlat.append(vertex.x)
            vertexFlat.append(vertex.y)
            vertexFlat.append(vertex.z)
        }

        return LiveLinkMessage.Part(
            id: meshPart.id,
            name: meshPart.part.name,
            semantic: meshPart.part.semantic.rawValue,
            vertices: vertexFlat,
            triangles: meshPart.triangles,
            triangleMaterialIndices: meshPart.triangleMaterialIndices,
            defaultMaterialIndex: meshPart.defaultMaterialIndex,
            materials: meshPart.materials.map { material in
                LiveLinkMessage.MaterialEntry(
                    color: material.baseColor.liveLinkRGBA,
                    name: material.name,
                    metallicness: material.physicalProperties?.metallicness,
                    roughness: material.physicalProperties?.roughness
                )
            }
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
#endif
