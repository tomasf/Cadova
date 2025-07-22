import Foundation
import Manifold3D

/// A unitless vector representing distances, sizes or scales in two dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector2D(x: 10, y: 15)
/// let v2: Vector2D = [10, 15]
/// ```
///
public struct Vector2D: ExpressibleByArrayLiteral, Hashable, Sendable, Codable {
    public typealias D = D2

    /// The x-component of the vector.
    public var x: Double

    /// The y-component of the vector.
    public var y: Double

    /// A vector with both components set to zero.
    public static let zero = Vector2D(0)

    /// Creates a vector with both `x` and `y` components set to the same value.
    ///
    /// - Parameter single: The value to set both `x` and `y`.
    ///
    public init(_ single: Double) {
        x = single
        y = single
    }

    /// Creates a vector with the specified `x` and `y` components.
    ///
    /// - Parameters:
    ///   - x: The x-component of the vector.
    ///   - y: The y-component of the vector.
    ///
    /// - Precondition: Both `x` and `y` must be finite (not NaN or infinite).
    ///
    public init(x: Double = 0, y: Double = 0) {
        precondition(x.isFinite, "Vector elements can't be NaN or infinite")
        precondition(y.isFinite, "Vector elements can't be NaN or infinite")
        self.x = x
        self.y = y
    }

    /// Creates a vector with the specified `x` and `y` components.
    ///
    /// - Parameters:
    ///   - x: The x-component of the vector.
    ///   - y: The y-component of the vector.
    ///
    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

    /// Creates a vector from an array literal of exactly two `Double` values.
    ///
    /// - Parameter arrayLiteral: An array literal containing exactly two elements.
    ///
    /// - Precondition: The array literal must contain exactly two elements.
    ///
    public init(arrayLiteral: Double...) {
        precondition(arrayLiteral.count == 2, "Vector2D requires exactly two elements")
        self.init(x: arrayLiteral[0], y: arrayLiteral[1])
    }

    /// Creates a vector by applying a getter closure to each axis.
    ///
    /// - Parameter getter: A closure that takes an `Axis2D` and returns the corresponding component value.
    ///
    public init(_ getter: (Axis2D) -> Double) {
        self.init(x: getter(.x), y: getter(.y))
    }

    /// Creates a vector with the `x` component set to the given value and `y` set to zero.
    ///
    /// - Parameter value: The value for the `x` component.
    ///
    public static func x(_ value: Double) -> Self { Self(x: value) }

    /// Creates a vector with the `y` component set to the given value and `x` set to zero.
    ///
    /// - Parameter value: The value for the `y` component.
    ///
    public static func y(_ value: Double) -> Self { Self(y: value) }

    /// Accesses or sets the component value for the specified axis.
    ///
    /// - Parameter axis: The axis (`.x` or `.y`) to access.
    ///
    /// - Returns: The component value at the specified axis.
    ///
    public subscript(_ axis: Axis2D) -> Double {
        get {
            switch axis {
            case .x: x
            case .y: y
            }
        }
        set {
            switch axis {
            case .x: x = newValue
            case .y: y = newValue
            }
        }
    }
}

public extension Vector2D {
    /// Calculates the angle of the straight line from this vector to another vector.
    ///
    /// - Parameter other: The other vector to calculate the angle to.
    ///
    /// - Returns: The angle from this vector to the other vector as an `Angle` value.
    ///
    func angle(to other: Vector2D) -> Angle {
        atan2(other.y - y, other.x - x)
    }
}

public extension Vector2D {
    /// The squared Euclidean norm (length squared) of the vector.
    ///
    /// This is equivalent to `x * x + y * y`.
    ///
    /// - Returns: The squared length of the vector.
    ///
    var squaredEuclideanNorm: Double {
        x * x + y * y
    }
}


extension Vector2D: Vector {
    public static let elementCount = 2

    /// Creates a vector from an array of elements.
    ///
    /// - Parameter e: An array of two `Double` elements representing the vector components.
    ///
    /// - Precondition: The array must contain exactly two elements.
    ///
    public init(elements e: [Double]) {
        precondition(e.count == 2, "Vector2D requires exactly two elements")
        self.init(e[0], e[1])
    }

    /// Accesses or sets the vector element at the specified index.
    ///
    /// - Parameter index: The index of the element (0 for `x`, 1 for `y`).
    ///
    /// - Returns: The value of the element at the given index.
    ///
    public subscript(_ index: Int) -> Double {
        get { [x, y][index] }
        set {
            switch index {
            case 0: x = newValue
            case 1: y = newValue
            default: assertionFailure("Invalid vector element index")
            }
        }
    }

    /// Returns a vector containing the minimum components from two vectors.
    ///
    /// - Parameters:
    ///   - a: The first vector.
    ///   - b: The second vector.
    ///
    /// - Returns: A vector where each component is the minimum of the corresponding components of `a` and `b`.
    ///
    public static func min(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y))
    }

    /// Returns a vector containing the maximum components from two vectors.
    ///
    /// - Parameters:
    ///   - a: The first vector.
    ///   - b: The second vector.
    ///
    /// - Returns: A vector where each component is the maximum of the corresponding components of `a` and `b`.
    ///
    public static func max(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y))
    }

    /// Converts this 2D vector into a 3D vector by adding a zero `z` component.
    public var vector3D: Vector3D { Vector3D(self) }
}

extension Vector2D: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "[%g, %g]", x, y)
    }
}

extension Vector2D {
    public func hash(into hasher: inout Hasher) {
        x.roundedForHash.hash(into: &hasher)
        y.roundedForHash.hash(into: &hasher)
    }

    public static func ==(_ lhs: Vector2D, _ rhs: Vector2D) -> Bool {
        lhs.x.roundedForHash == rhs.x.roundedForHash &&
        lhs.y.roundedForHash == rhs.y.roundedForHash
    }
}
