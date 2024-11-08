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

    public init(_ getter: (Self.Axis) -> Double) {
        self.init(x: getter(.x), y: getter(.y))
    }

    public var scadString: String {
        [x, y].scadString
    }

    public subscript(_ axis: Axis2D) -> Double {
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
    public typealias Axis = Axis2D
    public typealias Geometry = any Geometry2D
    public static let elementCount = 2

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

extension Vector2D: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "[%g, %g]", x, y)
    }
}
