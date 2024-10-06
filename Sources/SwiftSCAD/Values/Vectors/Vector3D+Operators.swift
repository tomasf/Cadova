import Foundation

public extension Vector3D {
    static func /(_ v: Vector3D, _ d: Double) -> Vector3D {
        return Vector3D(
            x: v.x / d,
            y: v.y / d,
            z: v.z / d
        )
    }

    static func *(_ v: Vector3D, _ d: Double) -> Vector3D {
        return Vector3D(
            x: v.x * d,
            y: v.y * d,
            z: v.z * d
        )
    }

    static prefix func -(_ v: Vector3D) -> Vector3D {
        return Vector3D(
            x: -v.x,
            y: -v.y,
            z: -v.z
        )
    }

    static func +(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x + v2.x,
            y: v1.y + v2.y,
            z: v1.z + v2.z
        )
    }

    static func -(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x - v2.x,
            y: v1.y - v2.y,
            z: v1.z - v2.z
        )
    }

    static func *(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x * v2.x,
            y: v1.y * v2.y,
            z: v1.z * v2.z
        )
    }

    static func /(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x / v2.x,
            y: v1.y / v2.y,
            z: v1.z / v2.z
        )
    }

    static func +(_ v: Vector3D, _ s: Double) -> Vector3D {
        return Vector3D(
            x: v.x + s,
            y: v.y + s,
            z: v.z + s
        )
    }

    static func -(_ v: Vector3D, _ s: Double) -> Vector3D {
        return Vector3D(
            x: v.x - s,
            y: v.y - s,
            z: v.z - s
        )
    }

    // Cross product
    static func ×(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        [
            v1.y * v2.z - v1.z * v2.y,
            v1.z * v2.x - v1.x * v2.z,
            v1.x * v2.y - v1.y * v2.x
        ]
    }

    // Dot product
    static func ⋅(_ v1: Vector3D, _ v2: Vector3D) -> Double {
        v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }
}
