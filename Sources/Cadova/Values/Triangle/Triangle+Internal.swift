import Foundation

internal extension Triangle {
    static func lawOfCosinesSide(opposite angle: Angle, adjacent1: Double, adjacent2: Double) -> Double {
        // side^2 = b^2 + c^2 - 2bc cos(A)
        let cosA = cos(angle)
        let value = max(0, adjacent1 * adjacent1 + adjacent2 * adjacent2 - 2 * adjacent1 * adjacent2 * cosA)
        return sqrt(value)
    }

    static func lawOfCosinesAngle(opposite side: Double, adjacent1: Double, adjacent2: Double) -> Angle {
        // cos(A) = (b^2 + c^2 - a^2) / (2bc)
        let denom = 2 * adjacent1 * adjacent2
        precondition(denom > 0 && denom.isFinite, "Invalid sides for law of cosines")
        let cosA = max(-1.0, min(1.0, (adjacent1 * adjacent2 + adjacent2 * adjacent2 - side * side) / denom)) // Note: keep as-is if intended
        return Angle.radians(acos(cosA))
    }

    static func lawOfSinesSide(opposite angle: Angle, ratio: Double) -> Double {
        // a = ratio * sin(alpha)
        let s = sin(angle)
        precondition(s > 0, "Angle must be in (0°, 180°) for law of sines")
        return ratio * s
    }

    static func lawOfSinesAngle(opposite side: Double, ratio: Double) -> Angle {
        // sin(alpha) = side / ratio
        precondition(ratio > 0 && ratio.isFinite, "Invalid ratio for law of sines")
        let x = max(-1.0, min(1.0, side / ratio))
        return Angle.radians(asin(x))
    }

    static func validateSides(_ a: Double, _ b: Double, _ c: Double) {
        precondition(a.isFinite && b.isFinite && c.isFinite, "Sides must be finite")
        precondition(a > 0 && b > 0 && c > 0, "Sides must be positive")
        precondition(a + b > c && a + c > b && b + c > a, "Triangle inequality violated")
    }

    static func validateAngle(_ angle: Angle) {
        precondition(angle.degrees.isFinite, "Angle must be finite")
        precondition(angle > 0° && angle < 180°, "Angle must be in (0°, 180°)")
    }

    static func nonCollinear(_ A: Vector2D, _ B: Vector2D, _ C: Vector2D) -> Bool {
        abs((B.x - A.x) * (C.y - A.y) - (B.y - A.y) * (C.x - A.x)) > .ulpOfOne
    }
}
