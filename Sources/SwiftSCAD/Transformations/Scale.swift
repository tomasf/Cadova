import Foundation

struct Scale3D: CoreGeometry3D {
    let scale: Vector3D
    let body: any Geometry3D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "scale",
            params: ["v": scale],
            body: body
        )
    }

    var bodyTransform: AffineTransform3D {
        .scaling(scale)
    }
}

public extension Geometry3D {
    func scaled(_ scale: Vector3D) -> any Geometry3D {
        Scale3D(scale: scale, body: self)
    }

    func scaled(_ factor: Double) -> any Geometry3D {
        Scale3D(scale: [factor, factor, factor], body: self)
    }

    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> any Geometry3D {
        Scale3D(scale: [x, y, z], body: self)
    }

    func flipped(along axes: Axes3D) -> any Geometry3D {
        Scale3D(scale: Vector3D(1, 1, 1).setting(axes: axes, to: -1), body: self)
    }
}


struct Scale2D: CoreGeometry2D {
    let scale: Vector2D
    let body: any Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "scale",
            params: ["v": scale],
            body: body
        )
    }

    var bodyTransform: AffineTransform3D {
        .scaling(x: scale.x, y: scale.y, z: 1)
    }
}

public extension Geometry2D {
    func scaled(_ scale: Vector2D) -> any Geometry2D {
        Scale2D(scale: scale, body: self)
    }

    func scaled(_ factor: Double) -> any Geometry2D {
        Scale2D(scale: [factor, factor], body: self)
    }

    func scaled(x: Double = 1, y: Double = 1) -> any Geometry2D {
        Scale2D(scale: [x, y], body: self)
    }

    func flipped(along axes: Axes2D) -> any Geometry2D {
        Scale2D(scale: Vector2D(1, 1).setting(axes: axes, to: -1), body: self)
    }
}
