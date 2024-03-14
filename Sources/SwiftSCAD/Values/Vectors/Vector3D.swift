import Foundation

/// A unitless vector representing distances, sizes or scales in three dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector3D(x: 10, y: 15, z: 5)
/// let v2: Vector3D = [10, 15, 5]
/// ```
public struct Vector3D: ExpressibleByArrayLiteral, SCADValue, Hashable {
    public var x: Double
    public var y: Double
    public var z: Double

    public static let zero = Vector3D(x: 0, y: 0, z: 0)

    public init(x: Double, y: Double, z: Double) {
        precondition(x.isFinite, "Vector elements can't be NaN or infinite")
        precondition(y.isFinite, "Vector elements can't be NaN or infinite")
        precondition(z.isFinite, "Vector elements can't be NaN or infinite")
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.init(x: x, y: y, z: z)
    }

    public init(_ xy: Vector2D, z: Double = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }

    public init(arrayLiteral: Double...) {
        precondition(arrayLiteral.count == 3, "Vector3D requires exactly three elements")
        self.init(x: arrayLiteral[0], y: arrayLiteral[1], z: arrayLiteral[2])
    }

    public var scadString: String {
        [x, y, z].scadString
    }
}

public extension Vector3D {
    /// Create a vector where some axes are set to a given value and the others are zero
    /// - Parameters:
    ///   - axis: The axes to set
    ///   - value: The value to use
    ///   - default: The value to use for the other axes
    init(axis: Axis3D, value: Double, default defaultValue: Double = 0) {
        let x = (axis == .x) ? value : defaultValue
        let y = (axis == .y) ? value : defaultValue
        let z = (axis == .z) ? value : defaultValue
        self.init(x, y, z)
    }

    /// Make a new vector where some of the dimensions are set to a new value
    /// - Parameters:
    ///   - axes: The axes to set
    ///   - value: The new value
    /// - Returns: A modified vector
    func setting(axes: Axes3D, to value: Double) -> Vector3D {
        Vector3D(
            x: axes.contains(.x) ? value : x,
            y: axes.contains(.y) ? value : y,
            z: axes.contains(.z) ? value : z
        )
    }

    subscript(_ axis: Axis3D) -> Double {
        switch axis {
        case .x: return x
        case .y: return y
        case .z: return z
        }
    }
}

public extension Vector3D {
    static func /(_ v: Vector3D, _ d: Double) -> Vector3D {
        return Vector3D(
            x: v.x / d,
            y: v.y / d,
            z: v.z / d
        )
    }

    static func *(_ v: Vector3D, _ d: Double) -> Vector3D {
        return Vector3D(
            x: v.x * d,
            y: v.y * d,
            z: v.z * d
        )
    }

    static prefix func -(_ v: Vector3D) -> Vector3D {
        return Vector3D(
            x: -v.x,
            y: -v.y,
            z: -v.z
        )
    }

    static func +(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x + v2.x,
            y: v1.y + v2.y,
            z: v1.z + v2.z
        )
    }

    static func -(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x - v2.x,
            y: v1.y - v2.y,
            z: v1.z - v2.z
        )
    }

    static func *(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x * v2.x,
            y: v1.y * v2.y,
            z: v1.z * v2.z
        )
    }

    static func /(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        return Vector3D(
            x: v1.x / v2.x,
            y: v1.y / v2.y,
            z: v1.z / v2.z
        )
    }

    static func +(_ v: Vector3D, _ s: Double) -> Vector3D {
        return Vector3D(
            x: v.x + s,
            y: v.y + s,
            z: v.z + s
        )
    }

    static func -(_ v: Vector3D, _ s: Double) -> Vector3D {
        return Vector3D(
            x: v.x - s,
            y: v.y - s,
            z: v.z - s
        )
    }

    // Cross product
    static func ×(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        [
            v1.y * v2.z - v1.z * v2.y,
            v1.z * v2.x - v1.x * v2.z,
            v1.x * v2.y - v1.y * v2.x
        ]
    }

    // Dot product
    static func ⋅(_ v1: Vector3D, _ v2: Vector3D) -> Double {
        v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }

    var xy: Vector2D {
        Vector2D(x:x, y:y)
    }
}

public extension Vector3D {
    /// Computes the magnitude (length) of the vector.
    var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
}

extension Vector3D: Vector {
    public typealias Transform = AffineTransform3D
    public static let elementCount = 3

    public var elements: [Double] {
        [x, y]
    }

    public init(elements e: [Double]) {
        self.init(e[0], e[1], e[2])
    }

    public subscript(_ index: Int) -> Double {
        [x, y, z][index]
    }

    public static func min(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y), z: Swift.min(a.z, b.z))
    }

    public static func max(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y), z: Swift.max(a.z, b.z))
    }
}
