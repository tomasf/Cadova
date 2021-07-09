import Foundation

public struct AffineTransform {
	public var values: [[Double]]

	public init(_ values: [[Double]]) {
		precondition(
			values.count == 4 && values.allSatisfy { $0.count == 4},
			"AffineTransform requires 16 (4 x 4) elements"
		)
		self.values = values
	}

	public static var identity: AffineTransform {
		AffineTransform([
			[1, 0, 0, 0],
			[0, 1, 0, 0],
			[0, 0, 1, 0],
			[0, 0, 0, 1]
		])
	}

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

	private static func rotation(x: Angle) -> AffineTransform {
		var transform = identity
		transform[1, 1] = cos(x)
		transform[1, 2] = -sin(x)
		transform[2, 1] = sin(x)
		transform[2, 2] = cos(x)
		return transform
	}

	private static func rotation(y: Angle) -> AffineTransform {
		var transform = identity
		transform[0, 0] = cos(y)
		transform[0, 2] = sin(y)
		transform[2, 0] = -sin(y)
		transform[2, 2] = cos(y)
		return transform
	}

	private static func rotation(z: Angle) -> AffineTransform {
		var transform = identity
		transform[0, 0] = cos(z)
		transform[0, 1] = -sin(z)
		transform[1, 0] = sin(z)
		transform[1, 1] = cos(z)
		return transform
	}

	public static func rotation(x: Angle = 0, y: Angle = 0, z: Angle = 0) -> AffineTransform {
		return identity
			.concatenated(with: rotation(x: x))
			.concatenated(with: rotation(y: y))
			.concatenated(with: rotation(z: z))
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

	public func rotated(x: Angle = 0, y: Angle = 0, z: Angle = 0) -> AffineTransform {
		concatenated(with: .rotation(x: x, y: y, z: z))
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform {
		concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
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
}


extension AffineTransform: SCADValue {
	public var scadString: String {
		values.scadString
	}
}


struct Transform: Geometry3D {
	let transform: AffineTransform
	let body: Geometry3D

	func scadString(environment: Environment) -> String {
		SCADCall(
			name: "multmatrix",
			params: ["m": transform],
			body: body
		)
		.scadString(environment: environment)
	}
}

public extension Geometry3D {
	func transformed(_ transform: AffineTransform) -> Geometry3D {
		Transform(transform: transform, body: self)
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Geometry3D {
		transformed(.shearing(axis, along: otherAxis, factor: factor))
	}
}
