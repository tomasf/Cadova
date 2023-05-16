import Foundation

struct Translate3D: CoreGeometry3D {
    let distance: Vector3D
    let body: Geometry3D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "translate",
            params: ["v": distance],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        .translation(distance)
    }
}

public extension Geometry3D {
    func translated(_ distance: Vector3D) -> Geometry3D {
        Translate3D(distance: distance, body: self)
    }

    func translated(_ distance: Vector2D) -> Geometry3D {
        Translate3D(distance: Vector3D(distance), body: self)
    }

    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Geometry3D {
        Translate3D(distance: [x, y, z], body: self)
    }
}


struct Translate2D: CoreGeometry2D {
    let distance: Vector2D
    let body: Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "translate",
            params: ["v": distance],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        .translation(Vector3D(distance))
    }
}

public extension Geometry2D {
    func translated(_ distance: Vector2D) -> Geometry2D {
        Translate2D(distance: distance, body: self)
    }

    func translated(x: Double = 0, y: Double = 0) -> Geometry2D {
        Translate2D(distance: [x, y], body: self)
    }
}
