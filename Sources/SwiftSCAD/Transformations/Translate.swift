import Foundation

struct Translate2D: WrappedGeometry2D {
    let body: any Geometry2D
    let distance: Vector2D

    var invocation: Invocation? {
        .init(name: "translate", parameters: ["v": distance])
    }

    var bodyTransform: AffineTransform3D {
        .translation(Vector3D(distance))
    }
}

struct Translate3D: WrappedGeometry3D {
    let body: any Geometry3D
    let distance: Vector3D

    var invocation: Invocation? {
        .init(name: "translate", parameters: ["v": distance])
    }

    var bodyTransform: AffineTransform3D {
        .translation(distance)
    }
}

public extension Geometry2D {
    func translated(_ distance: Vector2D) -> any Geometry2D {
        Translate2D(body: self, distance: distance)
    }

    func translated(x: Double = 0, y: Double = 0) -> any Geometry2D {
        translated([x, y])
    }
}

public extension Geometry3D {
    func translated(_ distance: Vector3D) -> any Geometry3D {
        Translate3D(body: self, distance: distance)
    }

    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> any Geometry3D {
        translated([x, y, z])
    }
}
