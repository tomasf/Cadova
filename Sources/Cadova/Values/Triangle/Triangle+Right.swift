import Foundation

public extension Triangle {
    // Right angle at gamma (default family). Legs: a, b. Hypotenuse: c.

    /// Creates a right triangle with right angle at `gamma` from legs `a` and `b`.
    static func right(a: Double, b: Double) -> Triangle {
        precondition(a.isFinite && a > 0 && b.isFinite && b > 0, "Legs must be positive and finite")
        return Triangle(a: a, b: b, includedGamma: 90°)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `a` and the `hypotenuse`.
    static func right(a: Double, hypotenuse: Double) -> Triangle {
        precondition(a.isFinite && a > 0 && hypotenuse.isFinite && hypotenuse > 0, "Sides must be positive and finite")
        precondition(hypotenuse > a, "Hypotenuse must be larger than the leg")
        let b2 = max(0, hypotenuse * hypotenuse - a * a)
        let b = sqrt(b2)
        return Triangle(a: a, b: b, includedGamma: 90°)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `b` and the `hypotenuse`.
    static func right(b: Double, hypotenuse: Double) -> Triangle {
        precondition(b.isFinite && b > 0 && hypotenuse.isFinite && hypotenuse > 0, "Sides must be positive and finite")
        precondition(hypotenuse > b, "Hypotenuse must be larger than the leg")
        let a2 = max(0, hypotenuse * hypotenuse - b * b)
        let a = sqrt(a2)
        return Triangle(a: a, b: b, includedGamma: 90°)
    }

    /// Creates a right triangle with right angle at `gamma` from hypotenuse and acute angle `alpha`.
    static func right(hypotenuse: Double, alpha: Angle) -> Triangle {
        precondition(hypotenuse.isFinite && hypotenuse > 0, "Side must be positive and finite")
        precondition(alpha > 0° && alpha < 90°, "Alpha must be in (0°, 90°) for a right triangle")
        return Triangle(c: hypotenuse, gamma: 90°, alpha: alpha)
    }

    /// Creates a right triangle with right angle at `gamma` from hypotenuse and acute angle `beta`.
    static func right(hypotenuse: Double, beta: Angle) -> Triangle {
        precondition(hypotenuse.isFinite && hypotenuse > 0, "Side must be positive and finite")
        precondition(beta > 0° && beta < 90°, "Beta must be in (0°, 90°) for a right triangle")
        return Triangle(c: hypotenuse, gamma: 90°, alpha: 90° - beta)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `a` and acute angle `alpha`.
    static func right(a: Double, alpha: Angle) -> Triangle {
        precondition(a.isFinite && a > 0, "Side must be positive and finite")
        precondition(alpha > 0° && alpha < 90°, "Alpha must be in (0°, 90°) for a right triangle")
        let beta = 90° - alpha
        return Triangle(a: a, alpha: alpha, beta: beta)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `b` and acute angle `beta`.
    static func right(b: Double, beta: Angle) -> Triangle {
        precondition(b.isFinite && b > 0, "Side must be positive and finite")
        precondition(beta > 0° && beta < 90°, "Beta must be in (0°, 90°) for a right triangle")
        return Triangle(b: b, beta: beta, gamma: 90°)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `b` and acute angle `alpha` (at A).
    /// Internally converts to `(b, beta)` with `beta = 90° - alpha`.
    static func right(b: Double, alpha: Angle) -> Triangle {
        precondition(b.isFinite && b > 0, "Side must be positive and finite")
        precondition(alpha > 0° && alpha < 90°, "Alpha must be in (0°, 90°) for a right triangle")
        let beta = 90° - alpha
        return right(b: b, beta: beta)
    }

    /// Creates a right triangle with right angle at `gamma` from leg `a` and acute angle `beta` (at B).
    /// Internally converts to `(a, alpha)` with `alpha = 90° - beta`.
    static func right(a: Double, beta: Angle) -> Triangle {
        precondition(a.isFinite && a > 0, "Side must be positive and finite")
        precondition(beta > 0° && beta < 90°, "Beta must be in (0°, 90°) for a right triangle")
        let alpha = 90° - beta
        return right(a: a, alpha: alpha)
    }
}
