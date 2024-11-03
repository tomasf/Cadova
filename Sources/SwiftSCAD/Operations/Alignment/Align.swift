import Foundation

internal struct Align<V: Vector> {
    let content: V.Geometry
    let alignment: GeometryAlignment<V>
}

extension Align<Vector2D>: Geometry2D, Shape2D {
    var body: any Geometry2D {
        readEnvironment { environment in
            let boundary = content.evaluated(in: environment).boundary
            let translation = boundary.boundingBox?.translation(for: alignment) ?? .zero
            content
                .translated(translation)
        }
    }
}

extension Align<Vector3D>: Geometry3D, Shape3D {
    var body: any Geometry3D {
        readEnvironment { environment in
            let boundary = content.evaluated(in: environment).boundary
            let translation = boundary.boundingBox?.translation(for: alignment) ?? .zero
            content
                .translated(translation)
        }
    }
}
