import Foundation

/// A unitless vector representing distances, sizes or scales in two dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector2D(x: 10, y: 15)
/// let v2: Vector2D = [10, 15]
/// ```
///
public struct Vector2D: ExpressibleByArrayLiteral, SCADValue, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public static let zero = Vector2D(0)

    public init(_ single: Double) {
        x = single
        y = single
    }

    public init(x: Double = 0, y: Double = 0) {
        precondition(x.isFinite, "Vector elements can't be NaN or infinite")
        precondition(y.isFinite, "Vector elements can't be NaN or infinite")
        self.x = x
        self.y = y
    }

    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

    public init(arrayLiteral: Double...) {
        precondition(arrayLiteral.count == 2, "Vector2D requires exactly two elements")
        self.init(x: arrayLiteral[0], y: arrayLiteral[1])
    }

    public init(_ getter: (Axes.Axis) -> Double) {
        self.init(x: getter(.x), y: getter(.y))
    }

    public var scadString: String {
        [x, y].scadString
    }
}

public extension Vector2D {
    /// Create a vector where some axes are set to a given value and the others are zero
    /// - Parameters:
    ///   - axis: The axes to set
    ///   - value: The value to use
    ///   - default: The value to use for the other axes

    init(axis: Axis2D, value: Double, default defaultValue: Double = 0) {
        self.init(
            x: (axis == .x) ? value : defaultValue,
            y: (axis == .y) ? value : defaultValue
        )
    }

    internal func with(_ axes: Axes2D, as value: Double) -> Vector2D {
        Vector2D(
            x: axes.contains(.x) ? value : x,
            y: axes.contains(.y) ? value : y
        )
    }

    /// Make a new vector by changing one element
    /// - Parameters:
    ///   - axis: The axis to change
    ///   - value: The new value
    /// - Returns: A modified vector
    func with(_ axis: Axis2D, as value: Double) -> Vector2D {
        Vector2D(
            x: axis == .x ? value : x,
            y: axis == .y ? value : y
        )
    }

    subscript(_ axis: Axis2D) -> Double {
        switch axis {
        case .x: return x
        case .y: return y
        }
    }
}

public extension Vector2D {
    /// Calculate the angle of a straight line between this point and another point
    func angle(to other: Vector2D) -> Angle {
        atan2(other.y - y, other.x - x)
    }
}

public extension Vector2D {
    var squaredEuclideanNorm: Double {
        x * x + y * y
    }
}


extension Vector2D: Vector {
    public typealias Transform = AffineTransform2D
    public typealias Axes = Axes2D
    public typealias Geometry = any Geometry2D
    public static let elementCount = 2

    public var elements: [Double] {
        [x, y]
    }

    public init(elements e: [Double]) {
        self.init(e[0], e[1])
    }

    public static func min(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y))
    }

    public static func max(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y))
    }
}

extension Vector2D: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "[%g, %g]", x, y)
    }
}
