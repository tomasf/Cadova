import Foundation

public extension Vector2D {
    static func +(_ v: Vector2D, _ s: Double) -> Vector2D {
        Vector2D(
            x: v.x + s,
            y: v.y + s
        )
    }

    static func -(_ v: Vector2D, _ s: Double) -> Vector2D {
        Vector2D(
            x: v.x - s,
            y: v.y - s
        )
    }

    static func *(_ v: Vector2D, _ d: Double) -> Vector2D {
        Vector2D(
            x: v.x * d,
            y: v.y * d
        )
    }

    static func /(_ v: Vector2D, _ d: Double) -> Vector2D {
        Vector2D(
            x: v.x / d,
            y: v.y / d
        )
    }
}

public extension Vector2D {
    static func +(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x + v2.x,
            y: v1.y + v2.y
        )
    }

    static func -(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x - v2.x,
            y: v1.y - v2.y
        )
    }

    static func *(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x * v2.x,
            y: v1.y * v2.y
        )
    }

    static func /(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x / v2.x,
            y: v1.y / v2.y
        )
    }
}

public extension Vector2D {
    static prefix func -(_ v: Vector2D) -> Vector2D {
        v * -1
    }

    // Cross product
    static func ×(v1: Vector2D, v2: Vector2D) -> Double {
        v1.x * v2.y - v1.y * v2.x
    }

    // Dot product
    static func ⋅(v1: Vector2D, v2: Vector2D) -> Double {
        v1.x * v2.x + v1.y * v2.y
    }
}

public extension Vector2D {
    static func += (lhs: inout Vector2D, rhs: Double) { lhs = lhs + rhs }
    static func -= (lhs: inout Vector2D, rhs: Double) { lhs = lhs - rhs }
    static func *= (lhs: inout Vector2D, rhs: Double) { lhs = lhs * rhs }
    static func /= (lhs: inout Vector2D, rhs: Double) { lhs = lhs / rhs }

    static func += (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs + rhs }
    static func -= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs - rhs }
    static func *= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs * rhs }
    static func /= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs / rhs }
}
