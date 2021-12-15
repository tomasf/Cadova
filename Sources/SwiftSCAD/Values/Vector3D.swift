import Foundation
import simd

/// A unitless vector representing distances, sizes or scales in three dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector3D(x: 10, y: 15, z: 5)
/// let v2: Vector3D = [10, 15, 5]
/// ```
public struct Vector3D: ExpressibleByArrayLiteral, SCADValue, Equatable {
	public let x: Double
	public let y: Double
	public let z: Double

	public static let zero = Vector3D(x: 0, y: 0, z: 0)

	public init(x: Double, y: Double, z: Double) {
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
    ///
	init(axis: Axis3D, value: Double) {
		let x = (axis == .x) ? value : 0
		let y = (axis == .y) ? value : 0
		let z = (axis == .z) ? value : 0
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

	var xy: Vector2D {
		Vector2D(x:x, y:y)
	}
}

public extension Vector3D {
    /// Calculate the distance from this point to another point in 3D space
	func distance(to other: Vector3D) -> Double {
		sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2))
	}

    /// Calculate a point at a given fraction along a straight line to another point
	func point(alongLineTo other: Vector3D, at fraction: Double) -> Vector3D {
		self + (other - self) * fraction
	}
}

internal extension Vector3D {
    var simd4: SIMD4<Double> {
        SIMD4(x, y, z, 1.0)
    }

    init(simd4 v: SIMD4<Double>) {
        self.init(v[0], v[1], v[2])
    }
}
