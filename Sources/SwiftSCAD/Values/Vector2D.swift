import Foundation
import simd

/// A unitless vector representing distances, sizes or scales in two dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector2D(x: 10, y: 15)
/// let v2: Vector2D = [10, 15]
/// ```
///
public struct Vector2D: ExpressibleByArrayLiteral, SCADValue, Hashable {
	public let x: Double
	public let y: Double

	public static let zero = Vector2D(x: 0, y: 0)

	public init(x: Double, y: Double) {
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

	init(axis: Axis2D, value: Double) {
		let x = (axis == .x) ? value : 0
		let y = (axis == .y) ? value : 0
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
}

public extension Vector2D {
    /// Calculate the distance from this point to another point in 2D space
	func distance(to other: Vector2D) -> Double {
		sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
	}

    /// Calculate the angle of a straight line between this point and another point
	func angle(to other: Vector2D) -> Angle {
		Angle(radians: atan2(other.y - y, other.x - x))
	}

    /// Calculate a point at a given fraction along a straight line to another point
	func point(alongLineTo other: Vector2D, at fraction: Double) -> Vector2D {
		self + (other - self) * fraction
	}
}

internal extension Vector2D {
    var simd3: SIMD3<Double> {
        SIMD3(x, y, 1.0)
    }

    init(simd3 v: SIMD3<Double>) {
        self.init(x: v[0], y: v[1])
    }
}
