import Foundation

struct Scale2D: WrapperGeometry2D {
    let body: any Geometry2D
    let scale: Vector2D

    var invocation: Invocation? {
        .init(name: "scale", parameters: ["v": scale])
    }

    var bodyTransform: AffineTransform3D {
        .scaling(x: scale.x, y: scale.y, z: 1)
    }
}

struct Scale3D: WrapperGeometry3D {
    let body: any Geometry3D
    let scale: Vector3D

    var invocation: Invocation? {
        .init(name: "scale", parameters: ["v": scale])
    }

    var bodyTransform: AffineTransform3D {
        .scaling(scale)
    }
}

public extension Geometry2D {
    func scaled(_ scale: Vector2D) -> any Geometry2D {
        Scale2D(body: self, scale: scale)
    }

    func scaled(_ factor: Double) -> any Geometry2D {
        scaled(Vector2D(factor, factor))
    }

    func scaled(x: Double = 1, y: Double = 1) -> any Geometry2D {
        scaled(Vector2D(x, y))
    }

    func flipped(along axes: Axes2D) -> any Geometry2D {
        scaled(Vector2D(1, 1).setting(axes: axes, to: -1))
    }
}

public extension Geometry3D {
    func scaled(_ scale: Vector3D) -> any Geometry3D {
        Scale3D(body: self, scale: scale)
    }

    func scaled(_ factor: Double) -> any Geometry3D {
        scaled(Vector3D(factor, factor, factor))
    }

    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> any Geometry3D {
        scaled(Vector3D(x, y, z))
    }

    func flipped(along axes: Axes3D) -> any Geometry3D {
        scaled(Vector3D(1, 1, 1).setting(axes: axes, to: -1))
    }
}
