import Foundation

public extension Triangle {
    // MARK: - SSS

    /// Initialize from three sides (SSS).
    ///
    /// - Parameters:
    ///   - a: Side opposite `alpha`. Must be positive and finite.
    ///   - b: Side opposite `beta`. Must be positive and finite.
    ///   - c: Side opposite `gamma`. Must be positive and finite.
    init(a: Double, b: Double, c: Double) {
        Self.validateSides(a, b, c)

        let alpha = Self.lawOfCosinesAngle(opposite: a, adjacent1: b, adjacent2: c)
        let beta = Self.lawOfCosinesAngle(opposite: b, adjacent1: a, adjacent2: c)
        let gamma = 180° - alpha - beta

        Self.validateAngle(alpha)
        Self.validateAngle(beta)
        Self.validateAngle(gamma)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    /// Initialize from three 2D points defining the triangle's vertices.
    ///
    /// The points are interpreted as vertices A, B, C in that order. Sides are derived as:
    /// - `a = |BC|` (opposite angle at A),
    /// - `b = |CA|` (opposite angle at B),
    /// - `c = |AB|` (opposite angle at C).
    ///
    /// - Parameters:
    ///   - A: Vertex A.
    ///   - B: Vertex B.
    ///   - C: Vertex C.
    /// - Precondition:
    ///   - Points must be finite, pairwise distinct, and non-collinear.
    init(A: Vector2D, B: Vector2D, C: Vector2D) {
        // Distinct points
        precondition(A != B && B != C && C != A, "Triangle points must be distinct")

        // Non-collinear
        precondition(
            abs((B.x - A.x) * (C.y - A.y) - (B.y - A.y) * (C.x - A.x)) > .ulpOfOne,
            "Triangle points must be non-collinear"
        )

        self.init(a: (B - C).magnitude, b: (C - A).magnitude, c: (A - B).magnitude)
    }

    // MARK: - SAS (side-angle-side, included angle between the two sides)

    /// Initialize from sides `b` and `c` with included angle `alpha` (SAS).
    ///
    /// - Parameters:
    ///   - b: Side opposite `beta`.
    ///   - c: Side opposite `gamma`.
    ///   - alpha: Included angle between `b` and `c`, opposite `a`.
    init(b: Double, c: Double, includedAlpha alpha: Angle) {
        Self.validateSides(b, c, max(1e-12, b + c - 1e-12)) // prelim finite/positive check
        Self.validateAngle(alpha)

        let a = Self.lawOfCosinesSide(opposite: alpha, adjacent1: b, adjacent2: c)
        Self.validateSides(a, b, c)

        let beta = Self.lawOfCosinesAngle(opposite: b, adjacent1: a, adjacent2: c)
        let gamma = 180° - alpha - beta

        Self.validateAngle(beta)
        Self.validateAngle(gamma)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    /// Initialize from sides `a` and `c` with included angle `beta` (SAS).
    init(a: Double, c: Double, includedBeta beta: Angle) {
        Self.validateSides(a, c, max(1e-12, a + c - 1e-12))
        Self.validateAngle(beta)

        let b = Self.lawOfCosinesSide(opposite: beta, adjacent1: a, adjacent2: c)
        Self.validateSides(a, b, c)

        let alpha = Self.lawOfCosinesAngle(opposite: a, adjacent1: b, adjacent2: c)
        let gamma = 180° - alpha - beta

        Self.validateAngle(alpha)
        Self.validateAngle(gamma)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    /// Initialize from sides `a` and `b` with included angle `gamma` (SAS).
    init(a: Double, b: Double, includedGamma gamma: Angle) {
        Self.validateSides(a, b, max(1e-12, a + b - 1e-12))
        Self.validateAngle(gamma)

        let c = Self.lawOfCosinesSide(opposite: gamma, adjacent1: a, adjacent2: b)
        Self.validateSides(a, b, c)

        let alpha = Self.lawOfCosinesAngle(opposite: a, adjacent1: b, adjacent2: c)
        let beta = 180° - alpha - gamma

        Self.validateAngle(alpha)
        Self.validateAngle(beta)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    // MARK: - ASA / AAS (two angles and one side)

    /// Initialize from side `a` and angles `alpha` and `beta` (ASA/AAS).
    ///
    /// - Parameters:
    ///   - a: Side opposite `alpha`.
    ///   - alpha: Angle opposite `a`.
    ///   - beta: Angle opposite `b`.
    init(a: Double, alpha: Angle, beta: Angle) {
        precondition(a.isFinite && a > 0, "a must be a positive, finite number")
        Self.validateAngle(alpha)
        Self.validateAngle(beta)

        let gamma = 180° - alpha - beta
        Self.validateAngle(gamma)

        // Law of sines: a / sin(alpha) = b / sin(beta) = c / sin(gamma)
        let ratio = a / sin(alpha)
        let b = ratio * sin(beta)
        let c = ratio * sin(gamma)

        Self.validateSides(a, b, c)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    /// Initialize from side `b` and angles `beta` and `gamma` (ASA/AAS).
    init(b: Double, beta: Angle, gamma: Angle) {
        precondition(b.isFinite && b > 0, "b must be a positive, finite number")
        Self.validateAngle(beta)
        Self.validateAngle(gamma)

        let alpha = 180° - beta - gamma
        Self.validateAngle(alpha)

        let ratio = b / sin(beta)
        let a = ratio * sin(alpha)
        let c = ratio * sin(gamma)

        Self.validateSides(a, b, c)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }

    /// Initialize from side `c` and angles `gamma` and `alpha` (ASA/AAS).
    init(c: Double, gamma: Angle, alpha: Angle) {
        precondition(c.isFinite && c > 0, "c must be a positive, finite number")
        Self.validateAngle(gamma)
        Self.validateAngle(alpha)

        let beta = 180° - gamma - alpha
        Self.validateAngle(beta)

        let ratio = c / sin(gamma)
        let a = ratio * sin(alpha)
        let b = ratio * sin(beta)

        Self.validateSides(a, b, c)

        self.init(a: a, b: b, c: c, alpha: alpha, beta: beta, gamma: gamma)
    }
}
