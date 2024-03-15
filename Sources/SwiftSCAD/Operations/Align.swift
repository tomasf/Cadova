import Foundation

public struct Align2D: Shape2D {
    let content: any Geometry2D
    let alignment: GeometryAlignment2D

    public var body: any Geometry2D {
        EnvironmentReader { environment in
            let bounds = content.output(in: environment).boundary.boundingBox
            let translation = bounds?.translation(for: alignment) ?? .zero
            content
                .translated(translation)
        }
    }
}

public struct Align3D: Shape3D {
    let content: any Geometry3D
    let alignment: GeometryAlignment3D

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            let bounds = content.output(in: environment).boundary.boundingBox
            let translation = bounds?.translation(for: alignment) ?? .zero
            content
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

public extension Geometry2D {
    func aligned(with alignment: GeometryAlignment2D...) -> any Geometry2D {
        Align2D(content: self, alignment: .init(merging: alignment))
    }
}

public extension Geometry3D {
    func aligned(with alignment: GeometryAlignment3D...) -> any Geometry3D {
        Align3D(content: self, alignment: .init(merging: alignment))
    }
}
