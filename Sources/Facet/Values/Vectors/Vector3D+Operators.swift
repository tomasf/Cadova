import Foundation

public extension Vector3D {
    static func +(_ v: Vector3D, _ s: Double) -> Vector3D {
        Vector3D(
            x: v.x + s,
            y: v.y + s,
            z: v.z + s
        )
    }

    static func -(_ v: Vector3D, _ s: Double) -> Vector3D {
        Vector3D(
            x: v.x - s,
            y: v.y - s,
            z: v.z - s
        )
    }

    static func *(_ v: Vector3D, _ d: Double) -> Vector3D {
        Vector3D(
            x: v.x * d,
            y: v.y * d,
            z: v.z * d
        )
    }

    static func /(_ v: Vector3D, _ d: Double) -> Vector3D {
        Vector3D(
            x: v.x / d,
            y: v.y / d,
            z: v.z / d
        )
    }
}

public extension Vector3D {
    static func +(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x + v2.x,
            y: v1.y + v2.y,
            z: v1.z + v2.z
        )
    }

    static func -(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x - v2.x,
            y: v1.y - v2.y,
            z: v1.z - v2.z
        )
    }

    static func *(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x * v2.x,
            y: v1.y * v2.y,
            z: v1.z * v2.z
        )
    }

    static func /(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x / v2.x,
            y: v1.y / v2.y,
            z: v1.z / v2.z
        )
    }
}

public extension Vector3D {
    static prefix func -(_ v: Vector3D) -> Vector3D {
        Vector3D(
            x: -v.x,
            y: -v.y,
            z: -v.z
        )
    }

    // Cross product
    static func ×(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.y * v2.z - v1.z * v2.y,
            y: v1.z * v2.x - v1.x * v2.z,
            z: v1.x * v2.y - v1.y * v2.x
        )
    }

    // Dot product
    static func ⋅(_ v1: Vector3D, _ v2: Vector3D) -> Double {
        v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }
}

public extension Vector3D {
    static func += (lhs: inout Vector3D, rhs: Double) { lhs = lhs + rhs }
    static func -= (lhs: inout Vector3D, rhs: Double) { lhs = lhs - rhs }
    static func *= (lhs: inout Vector3D, rhs: Double) { lhs = lhs * rhs }
    static func /= (lhs: inout Vector3D, rhs: Double) { lhs = lhs / rhs }

    static func += (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs + rhs }
    static func -= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs - rhs }
    static func *= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs * rhs }
    static func /= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs / rhs }

    static func ×= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs × rhs }
}
