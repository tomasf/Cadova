import Foundation

/// A geometric vector in 2D or 3D space.
///
/// This protocol defines common vector operations. You typically work with the concrete types
/// ``Vector2D`` and ``Vector3D`` rather than this protocol directly.
///
public protocol Vector: Hashable, Sendable, Codable, CustomDebugStringConvertible,
                        Collection where Element == Double {
    associatedtype D: Dimensionality where D.Vector == Self

    static var zero: Self { get }
    init(_ single: Double)

    static func min(_ a: Self, _ b: Self) -> Self
    static func max(_ a: Self, _ b: Self) -> Self

    // Operators
    static prefix func -(_ v: Self) -> Self

    static func +(_ v1: Self, _ v2: Self) -> Self
    static func -(_ v1: Self, _ v2: Self) -> Self
    static func *(_ v1: Self, _ v2: Self) -> Self
    static func /(_ v1: Self, _ v2: Self) -> Self

    static func +(_ v: Self, _ s: Double) -> Self
    static func -(_ v: Self, _ s: Double) -> Self
    static func *(_ v: Self, _ d: Double) -> Self
    static func /(_ v: Self, _ d: Double) -> Self

    static func +(_ s: Double, _ v: Self) -> Self
    static func *(_ d: Double, _ v: Self) -> Self

    static func ⋅(_ v1: Self, _ v2: Self) -> Double

    // Magnitude and normalization
    var magnitude: Double { get }
    var squaredEuclideanNorm: Double { get }
    var normalized: Self { get }

    // Hypotenuse
    func distance(to other: Self) -> Double
    func point(alongLineTo other: Self, at fraction: Double) -> Self

    // Access by axis
    init(_ axis: D.Axis, value: Double)
    init(_ getter: (D.Axis) -> Double)
    func with(_ axis: D.Axis, as value: Double) -> Self
    subscript(_ axis: D.Axis) -> Double { get set }

    // Access by index
    static var elementCount: Int { get }
    init(elements: [Double])
    subscript(_ index: Int) -> Double { get set }

    var vector3D: Vector3D { get }
}

public extension Vector {
    func index(after i: Int) -> Int { i + 1 }
    var startIndex: Int { 0 }
    var endIndex: Int { Self.elementCount }

    /// Returns a normalized version of the vector with a magnitude of 1.
    var normalized: Self {
        guard magnitude > 0 else { return self }
        return self / magnitude
    }

    /// The magnitude (length) of the vector.
    var magnitude: Double {
        sqrt(squaredEuclideanNorm)
    }

    /// Calculate a point at a given fraction along a straight line to another point
    func point(alongLineTo other: Self, at fraction: Double) -> Self {
        self + (other - self) * fraction
    }

    /// Calculate the distance from this point to another point in 2D space
    func distance(to other: Self) -> Double {
        (other - self).magnitude
    }

    /// Create a vector where some axes are set to a given value and the others are zero
    /// - Parameters:
    ///   - axis: The axes to set
    ///   - value: The value to use
    init(_ axis: D.Axis, value: Double) {
        self.init { $0 == axis ? value : 0 }
    }

    /// Make a new vector by changing one element
    /// - Parameters:
    ///   - axis: The axis to change
    ///   - value: The new value
    /// - Returns: A modified vector
    func with(_ axis: D.Axis, as value: Double) -> Self {
        .init { $0 == axis ? value : self[$0] }
    }
}

internal extension Vector {
    var vector3D: Vector3D {
        switch self {
        case let self as Vector3D: self
        case let self as Vector2D: .init(self.x, self.y, 0)
        default: preconditionFailure()
        }
    }

    func with(_ axes: D.Axes, as value: Double) -> Self {
        .init { axes.contains($0) ? value : self[$0] }
    }
}

/// Linearly interpolates between two vectors.
///
/// - Parameters:
///   - a: The starting vector.
///   - b: The ending vector.
///   - t: The interpolation factor, where 0 returns `a` and 1 returns `b`.
/// - Returns: The interpolated vector.
///
public func lerp<V: Vector>(_ a: V, _ b: V, t: Double) -> V {
    a + (b - a) * t
}
