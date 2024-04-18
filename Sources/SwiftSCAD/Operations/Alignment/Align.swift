import Foundation

public struct Align2D: Shape2D {
    let content: any Geometry2D
    let alignment: GeometryAlignment2D

    public var body: any Geometry2D {
        EnvironmentReader { environment in
            let output = content.output(in: environment)
            let translation = output.boundary.boundingBox?.translation(for: alignment) ?? .zero
            output
                .translated(translation)
        }
    }
}

public struct Align3D: Shape3D {
    let content: any Geometry3D
    let alignment: GeometryAlignment3D

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            let output = content.output(in: environment)
            let translation = output.boundary.boundingBox?.translation(for: alignment) ?? .zero
            output
                .translated(translation)
        }
    }
}

extension BoundingBox2D {
    func translation(for alignment: GeometryAlignment2D) -> Vector2D {
        let x = (alignment.x?.factor).map { -minimum.x - size.x * $0 } ?? 0
        let y = (alignment.y?.factor).map { -minimum.y - size.y * $0 } ?? 0
        return Vector2D(x, y)
    }
}

extension BoundingBox3D {
    func translation(for alignment: GeometryAlignment3D) -> Vector3D {
        let x = (alignment.x?.factor).map { -minimum.x - size.x * $0 } ?? 0
        let y = (alignment.y?.factor).map { -minimum.y - size.y * $0 } ?? 0
        let z = (alignment.z?.factor).map { -minimum.z - size.z * $0 } ?? 0
        return Vector3D(x, y, z)
    }
}
