import Foundation

/// A helper for working with general triangles.
///
/// Semantics:
/// - `a`, `b`, `c` are the three sides of the triangle.
/// - `alpha` is the internal angle opposite side `a`.
/// - `beta` is the internal angle opposite side `b`.
/// - `gamma` is the internal angle opposite side `c`.
/// - The sum of the internal angles satisfies `alpha + beta + gamma = 180°`.
///
/// Initialization:
/// - You can initialize using any two independent values that include at least one side
///   (e.g. SSS, SAS, ASA/AAS). The remaining properties are solved.
/// - All sides must be positive and finite. All angles must be finite and strictly between `0°` and `180°`.
///
public struct Triangle: Sendable, Hashable, Codable {
    /// Side opposite `alpha`.
    public let a: Double
    /// Side opposite `beta`.
    public let b: Double
    /// Side opposite `gamma`.
    public let c: Double

    /// Angle opposite `a`.
    public let alpha: Angle
    /// Angle opposite `b`.
    public let beta: Angle
    /// Angle opposite `c`.
    public let gamma: Angle

    internal init(a: Double, b: Double, c: Double, alpha: Angle, beta: Angle, gamma: Angle) {
        self.a = a
        self.b = b
        self.c = c
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
    }
}
