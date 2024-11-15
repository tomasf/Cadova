import Foundation

precedencegroup CrossProductPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
    lowerThan: MultiplicationPrecedence
}

infix operator × : CrossProductPrecedence
infix operator ⋅ : MultiplicationPrecedence
infix operator ×= : AssignmentPrecedence

public protocol Vector: Sendable, CustomDebugStringConvertible, Collection where Element == Double {
    associatedtype Axis: SwiftSCAD.Axis
    typealias Axes = Set<Axis>
    typealias Alignment = GeometryAlignment<Self>
    
    associatedtype Transform: AffineTransform where Transform.V == Self
    associatedtype Geometry

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

    static func ⋅(_ v1: Self, _ v2: Self) -> Double

    // Magnitude and normalization
    var magnitude: Double { get }
    var squaredEuclideanNorm: Double { get }
    var normalized: Self { get }

    // Hypotenuse
    func distance(to other: Self) -> Double
    func point(alongLineTo other: Self, at fraction: Double) -> Self

    // Access by axis
    init(_ axis: Axis, value: Double)
    init(_ getter: (Axis) -> Double)
    func with(_ axis: Axis, as value: Double) -> Self
    subscript(_ axis: Axis) -> Double { get }

    // Access by index
    static var elementCount: Int { get }
    init(elements: [Double])
    subscript(_ index: Int) -> Double { get }
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
    init(_ axis: Axis, value: Double) {
        self.init { $0 == axis ? value : 0 }
    }

    /// Make a new vector by changing one element
    /// - Parameters:
    ///   - axis: The axis to change
    ///   - value: The new value
    /// - Returns: A modified vector
    func with(_ axis: Axis, as value: Double) -> Self {
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

    func with(_ axes: Axes, as value: Double) -> Self {
        .init { axes.contains($0) ? value : self[$0] }
    }
}
