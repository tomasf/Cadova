import Foundation
import Manifold3D

/// A unitless vector representing distances, sizes or scales in three dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector3D(x: 10, y: 15, z: 5)
/// let v2: Vector3D = [10, 15, 5]
/// ```
public struct Vector3D: ExpressibleByArrayLiteral, Hashable, Sendable, Codable {
    public typealias D = D3
    
    /// The x-component of the vector.
    public var x: Double
    /// The y-component of the vector.
    public var y: Double
    /// The z-component of the vector.
    public var z: Double

    /// A vector with all components set to zero.
    public static let zero = Vector3D(0)

    /// Creates a vector with all components set to the same value.
    ///
    /// - Parameter single: The value to set for `x`, `y`, and `z`.
    ///
    public init(_ single: Double) {
        x = single
        y = single
        z = single
    }

    /// Creates a vector with the specified `x`, `y`, and `z` components.
    ///
    /// - Parameters:
    ///   - x: The x-component of the vector. Default is 0.
    ///   - y: The y-component of the vector. Default is 0.
    ///   - z: The z-component of the vector. Default is 0.
    ///
    /// - Precondition: All components must be finite (not NaN or infinite).
    ///
    public init(x: Double = 0, y: Double = 0, z: Double = 0) {
        precondition(x.isFinite, "Vector elements can't be NaN or infinite")
        precondition(y.isFinite, "Vector elements can't be NaN or infinite")
        precondition(z.isFinite, "Vector elements can't be NaN or infinite")
        self.x = x
        self.y = y
        self.z = z
    }

    /// Creates a vector with the specified `x`, `y`, and `z` components.
    ///
    /// - Parameters:
    ///   - x: The x-component of the vector.
    ///   - y: The y-component of the vector.
    ///   - z: The z-component of the vector.
    ///
    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.init(x: x, y: y, z: z)
    }

    /// Creates a vector from a 2D vector and a `z` value.
    ///
    /// - Parameters:
    ///   - xy: The 2D vector providing the `x` and `y` components.
    ///   - z: The `z` component. Default is 0.
    ///
    public init(_ xy: Vector2D, z: Double = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }

    /// Creates a vector from an array literal of exactly three `Double` values.
    ///
    /// - Parameter arrayLiteral: An array literal containing exactly three elements.
    ///
    /// - Precondition: The array literal must contain exactly three elements.
    ///
    public init(arrayLiteral: Double...) {
        precondition(arrayLiteral.count == 3, "Vector3D requires exactly three elements")
        self.init(x: arrayLiteral[0], y: arrayLiteral[1], z: arrayLiteral[2])
    }

    /// Creates a vector by applying a getter closure to each axis.
    ///
    /// - Parameter getter: A closure that takes an `Axis3D` and returns the corresponding component value.
    ///
    public init(_ getter: (Axis3D) -> Double) {
        self.init(x: getter(.x), y: getter(.y), z: getter(.z))
    }

    /// Creates a vector with the `x` component set to the given value and `y`, `z` set to zero.
    ///
    /// - Parameter value: The value for the `x` component.
    ///
    public static func x(_ value: Double) -> Self { Self(x: value) }

    /// Creates a vector with the `y` component set to the given value and `x`, `z` set to zero.
    ///
    /// - Parameter value: The value for the `y` component.
    ///
    public static func y(_ value: Double) -> Self { Self(y: value) }

    /// Creates a vector with the `z` component set to the given value and `x`, `y` set to zero.
    ///
    /// - Parameter value: The value for the `z` component.
    ///
    public static func z(_ value: Double) -> Self { Self(z: value) }
}

public extension Vector3D {
    /// Accesses or sets the component value for the specified axis.
    ///
    /// - Parameter axis: The axis (`.x`, `.y`, or `.z`) to access.
    ///
    /// - Returns: The component value at the specified axis.
    ///
    subscript(_ axis: Axis3D) -> Double {
        get {
            switch axis {
            case .x: x
            case .y: y
            case .z: z
            }
        }
        set {
            switch axis {
            case .x: x = newValue
            case .y: y = newValue
            case .z: z = newValue
            }
        }
    }

    /// Calculates the angle between this vector and another vector, in radians.
    ///
    /// - Parameter other: The other vector to calculate the angle to.
    ///
    /// - Returns: The angle between the two vectors as an `Angle` value, representing the smallest rotation from this vector to the other.
    ///
    func angle(with other: Vector3D) -> Angle {
        let magnitudes = self.magnitude * other.magnitude
        guard magnitudes > 0 else {
            return 0°
        }

        return acos(((self ⋅ other) / magnitudes).clamped(to: -1.0...1.0))
    }

    /// The projection of this vector onto the XY plane as a 2D vector.
    ///
    /// This returns a `Vector2D` containing the `x` and `y` components of this vector.
    var xy: Vector2D {
        .init(x: x, y: y)
    }

    /// The squared Euclidean norm of the vector.
    ///
    /// This is the sum of the squares of the components of the vector.
    /// It is equivalent to the square of the magnitude, but faster to compute
    /// because it avoids a square root.
    var squaredEuclideanNorm: Double {
        x * x + y * y + z * z
    }
}

extension Vector3D: Vector {
    /// The associated transformation type for this vector.
    public typealias Transform = Transform3D

    /// The number of elements in the vector (always 3).
    public static let elementCount = 3

    /// Accesses or sets the vector element at the specified index.
    ///
    /// - Parameter index: The index of the element (0 for `x`, 1 for `y`, 2 for `z`).
    ///
    /// - Returns: The value of the element at the given index.
    ///
    public subscript(_ index: Int) -> Double {
        get { [x, y, z][index] }
        set {
            switch index {
            case 0: x = newValue
            case 1: y = newValue
            case 2: z = newValue
            default: assertionFailure("Invalid vector element index")
            }
        }
    }

    /// Creates a vector from an array of elements.
    ///
    /// - Parameter e: An array of three `Double` elements representing the vector components.
    ///
    /// - Precondition: The array must contain exactly three elements.
    ///
    public init(elements e: [Double]) {
        self.init(e[0], e[1], e[2])
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
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y), z: Swift.min(a.z, b.z))
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
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y), z: Swift.max(a.z, b.z))
    }

    /// Converts this 3D vector into itself (for protocol compatibility).
    public var vector3D: Vector3D { self }
}

extension Vector3D: CustomDebugStringConvertible {
    /// A textual representation of the vector for debugging.
    public var debugDescription: String {
        String(format: "[%g, %g, %g]", x, y, z)
    }
}

extension Vector3D {
    /// Hashes the vector using rounded values for stability.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    ///
    public func hash(into hasher: inout Hasher) {
        x.roundedForHash.hash(into: &hasher)
        y.roundedForHash.hash(into: &hasher)
        z.roundedForHash.hash(into: &hasher)
    }

    /// Compares two vectors using rounded values to allow tolerance.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side vector.
    ///   - rhs: The right-hand side vector.
    ///
    /// - Returns: `true` if the vectors are equal within the rounding tolerance.
    ///
    public static func ==(_ lhs: Vector3D, _ rhs: Vector3D) -> Bool {
        lhs.x.roundedForHash == rhs.x.roundedForHash &&
        lhs.y.roundedForHash == rhs.y.roundedForHash &&
        lhs.z.roundedForHash == rhs.z.roundedForHash
    }
}
