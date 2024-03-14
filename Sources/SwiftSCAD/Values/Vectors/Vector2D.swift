import Foundation

/// A unitless vector representing distances, sizes or scales in two dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector2D(x: 10, y: 15)
/// let v2: Vector2D = [10, 15]
/// ```
///
public struct Vector2D: ExpressibleByArrayLiteral, SCADValue, Hashable {
    public var x: Double
    public var y: Double

    public static let zero = Vector2D(x: 0, y: 0)

    public init(x: Double, y: Double) {
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
        let x = (axis == .x) ? value : defaultValue
        let y = (axis == .y) ? value : defaultValue
        self.init(x, y)
    }

    /// Make a new vector where some of the dimensions are set to a new value
    /// - Parameters:
    ///   - axes: The axes to set
    ///   - value: The new value
    /// - Returns: A modified vector

    func setting(axes: Axes2D, to value: Double) -> Vector2D {
        Vector2D(
            x: axes.contains(.x) ? value : x,
            y: axes.contains(.y) ? value : y
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
    static func /(_ v: Vector2D, _ d: Double) -> Vector2D {
        return Vector2D(
            x: v.x / d,
            y: v.y / d
        )
    }

    static func *(_ v: Vector2D, _ d: Double) -> Vector2D {
        return Vector2D(
            x: v.x * d,
            y: v.y * d
        )
    }

    static func *(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        return Vector2D(
            x: v1.x * v2.x,
            y: v1.y * v2.y
        )
    }

    static func /(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        return Vector2D(
            x: v1.x / v2.x,
            y: v1.y / v2.y
        )
    }

    static func +(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        return Vector2D(
            x: v1.x + v2.x,
            y: v1.y + v2.y
        )
    }

    static func -(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        return Vector2D(
            x: v1.x - v2.x,
            y: v1.y - v2.y
        )
    }

    static prefix func -(_ v: Vector2D) -> Vector2D {
        return Vector2D(
            x: -v.x,
            y: -v.y
        )
    }


    static func +(_ v: Vector2D, _ s: Double) -> Vector2D {
        return Vector2D(
            x: v.x + s,
            y: v.y + s
        )
    }

    static func -(_ v: Vector2D, _ s: Double) -> Vector2D {
        return Vector2D(
            x: v.x - s,
            y: v.y - s
        )
    }

    // Cross product
    static func ×(v1: Vector2D, v2: Vector2D) -> Double {
        return v1.x * v2.y - v1.y * v2.x
    }

    // Dot product
    static func ⋅(v1: Vector2D, v2: Vector2D) -> Double {
        v1.x * v2.x + v1.y * v2.y
    }
}

public extension Vector2D {
    /// Calculate the angle of a straight line between this point and another point
    func angle(to other: Vector2D) -> Angle {
        Angle(radians: atan2(other.y - y, other.x - x))
    }
}

public extension Vector2D {
    /// Computes the magnitude (length) of the vector.
    var magnitude: Double {
        sqrt(x * x + y * y)
    }
}


extension Vector2D: Vector {
    public typealias Transform = AffineTransform2D
    public static let elementCount = 2

    public var elements: [Double] {
        [x, y]
    }

    public init(elements e: [Double]) {
        self.init(e[0], e[1])
    }

    public subscript(_ index: Int) -> Double {
        [x, y][index]
    }

    public static func min(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y))
    }

    public static func max(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y))
    }

}
