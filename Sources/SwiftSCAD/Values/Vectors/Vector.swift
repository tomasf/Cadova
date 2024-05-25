import Foundation

public protocol Vector {
    associatedtype Axes: SwiftSCAD.Axes
    associatedtype Transform: AffineTransform where Transform.Vector == Self

    static var zero: Self { get }
    static prefix func -(_ v: Self) -> Self
    
    static func +(_ v1: Self, _ v2: Self) -> Self
    static func -(_ v1: Self, _ v2: Self) -> Self
    static func *(_ v1: Self, _ v2: Self) -> Self
    static func /(_ v1: Self, _ v2: Self) -> Self

    static func +(_ v: Self, _ s: Double) -> Self
    static func -(_ v: Self, _ s: Double) -> Self
    static func *(_ v: Self, _ d: Double) -> Self
    static func /(_ v: Self, _ d: Double) -> Self

    var magnitude: Double { get }
    var squaredEuclideanNorm: Double { get }
    var normalized: Self { get }
    func distance(to other: Self) -> Double
    func point(alongLineTo other: Self, at fraction: Double) -> Self

    init(axis: Axes.Axis, value: Double, default: Double)
    func with(_ axis: Axes.Axis, as value: Double) -> Self
    subscript(_ axis: Axes.Axis) -> Double { get }

    static var elementCount: Int { get }
    init(elements: [Double])
    var elements: [Double] { get }
    subscript(_ index: Int) -> Double { get }

    static func min(_ a: Self, _ b: Self) -> Self
    static func max(_ a: Self, _ b: Self) -> Self
}

public extension Vector {
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
}

infix operator ×
infix operator ⋅

internal extension Vector {
    var vector3D: Vector3D {
        if let v3d = self as? Vector3D {
            return v3d
        } else if let v2d = self as? Vector2D {
            return .init(v2d, z: 0)
        } else {
            preconditionFailure()
        }
    }
}
