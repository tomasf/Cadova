import Foundation

public struct AffineTransform {
	var values: [[Double]]

	public init(_ values: [[Double]]) {
		precondition(
			values.count == 4 && values.allSatisfy { $0.count == 4},
			"AffineTransform requires 16 (4 x 4) elements"
		)
		self.values = values
	}

	public subscript(_ row: Int, _ column: Int) -> Double {
		get {
			assert((0...3).contains(row), "Row index out of range")
			assert((0...3).contains(column), "Column index out of range")
			return values[row][column]
		}
		set {
			assert((0...3).contains(row), "Row index out of range")
			assert((0...3).contains(column), "Column index out of range")
			values[row][column] = newValue
		}
	}

	public static var identity: AffineTransform {
		AffineTransform([
			[1, 0, 0, 0],
			[0, 1, 0, 0],
			[0, 0, 1, 0],
			[0, 0, 0, 1]
		])
	}

	public func concatenated(with other: AffineTransform) -> AffineTransform {
		AffineTransform(
			(0..<4).map { row in
				(0..<4).map { column in
					(0..<4).map { i in
						other[row, i] * self[i, column]
					}.reduce(0, +)
				}
			}
		)
	}
}

extension AffineTransform {
	public static func translation(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform {
		var transform = identity
		transform[0, 3] = x
		transform[1, 3] = y
		transform[2, 3] = z
		return transform
	}

	public static func translation(_ v: Vector3D) -> AffineTransform {
		translation(x: v.x, y: v.y, z: v.z)
	}

	public static func scaling(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform {
		var transform = identity
		transform[0, 0] = x
		transform[1, 1] = y
		transform[2, 2] = z
		return transform
	}

	public static func scaling(_ v: Vector3D) -> AffineTransform {
		scaling(x: v.x, y: v.y, z: v.z)
	}

    public static func rotation(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform {
        var transform = identity
        transform[0, 0] = cos(y) * cos(z)
        transform[0, 1] = sin(x) * sin(y) * cos(z) - cos(x) * sin(z)
        transform[0, 2] = cos(x) * sin(y) * cos(z) + sin(z) * sin(x)
        transform[1, 0] = cos(y) * sin(z)
        transform[1, 1] = sin(x) * sin(y) * sin(z) + cos(x) * cos(z)
        transform[1, 2] = cos(x) * sin(y) * sin(z) - sin(x) * cos(z)
        transform[2, 0] = -sin(y)
        transform[2, 1] = sin(x) * cos(y)
        transform[2, 2] = cos(x) * cos(y)
        return transform
    }

	public static func rotation(_ a: [Angle]) -> AffineTransform {
		assert(a.count == 3, "Rotate expects three angles")
		return rotation(x: a[0], y: a[1], z: a[2])
	}

	public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform {
		precondition(axis != otherAxis, "Shearing requires two distinct axes")

		let order: [Axis3D] = [.x, .y, .z]
		let row = order.firstIndex(of: axis)!
		let column = order.firstIndex(of: otherAxis)!

		var t = AffineTransform.identity
		t[row, column] = factor
		return t
	}

	public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform {
		assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
		let factor = sin(angle) / sin(90° - angle)
		return shearing(axis, along: otherAxis, factor: factor)
	}
}

extension AffineTransform {
	public func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform {
		concatenated(with: .translation(x: x, y: y, z: z))
	}

	public func translated(_ v: Vector3D) -> AffineTransform {
		concatenated(with: .translation(v))
	}

	public func scaled(_ v: Vector3D) -> AffineTransform {
		concatenated(with: .scaling(v))
	}

	public func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform {
		concatenated(with: .scaling(x: x, y: y, z: z))
	}

	public func rotated(_ a: [Angle]) -> AffineTransform {
		concatenated(with: .rotation(a))
	}

	public func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform {
		concatenated(with: .rotation(x: x, y: y, z: z))
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform {
		concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform {
		concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
	}
}

extension AffineTransform {
    public init(_ transform2d: AffineTransform2D) {
        var transform = AffineTransform.identity

        transform[0, 0] = transform2d[0, 0]
        transform[0, 1] = transform2d[1, 0]
        transform[1, 0] = transform2d[0, 1]
        transform[1, 1] = transform2d[1, 1]

        transform[0, 3] = transform2d[2, 0]
        transform[1, 3] = transform2d[2, 1]

        self = transform
    }

    public var translation: Vector3D {
        Vector3D(
            x: self[0, 3],
            y: self[1, 3],
            z: self[2, 3]
        )
    }

    public func apply(to point: Vector3D) -> Vector3D {
        concatenated(with: .translation(point)).translation
    }
}

extension AffineTransform: SCADValue {
	public var scadString: String {
		values.scadString
	}
}
