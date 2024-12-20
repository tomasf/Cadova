import Foundation
import Manifold

struct ColorMapping: ResultElement {
    let mapping: [Mesh.OriginalID: Color]

    private init(mapping: [Mesh.OriginalID: Color]) {
        self.mapping = mapping
    }

    init(originalID: Mesh.OriginalID, color: Color) {
        self.init(mapping: [originalID: color])
    }

    static func combining(mappings: [ColorMapping]) -> ColorMapping {
        .init(mapping: mappings.reduce(into: [:]) { result, mapping in
            result.merge(mapping.mapping) { $1 }
        })
    }

    static func combine(elements: [ColorMapping], for operation: GeometryCombination) -> ColorMapping? {
        .combining(mappings: elements)
    }
}

internal struct ApplyColor: Geometry3D {
    let body: any Geometry3D
    let color: Color

    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        let newMesh = bodyOutput.manifold.asOriginal()
        var elements = bodyOutput.elements
        guard let originalID = newMesh.originalID else {
            preconditionFailure("Original mesh returned nil originalID")
        }

        elements[ColorMapping.self] = ColorMapping(originalID: originalID, color: color)
        return Output3D(manifold: newMesh, elements: elements)
    }
}
