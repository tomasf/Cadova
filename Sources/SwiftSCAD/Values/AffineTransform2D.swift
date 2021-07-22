import Foundation

public struct AffineTransform2D: Equatable {
	var values: [[Double]]

	public init(_ values: [[Double]]) {
		precondition(
			values.count == 3 && values.allSatisfy { $0.count == 3},
			"AffineTransform2D requires 9 (3 x 3) elements"
		)
		self.values = values
	}

	public subscript(_ row: Int, _ column: Int) -> Double {
		get {
			assert((0...2).contains(row), "Row index out of range")
			assert((0...2).contains(column), "Column index out of range")
			return values[row][column]
		}
		set {
			assert((0...2).contains(row), "Row index out of range")
			assert((0...2).contains(column), "Column index out of range")
			values[row][column] = newValue
		}
	}

	public static var identity: AffineTransform2D {
		AffineTransform2D([
			[1, 0, 0],
			[0, 1, 0],
			[0, 0, 1]
		])
	}

	public func concatenated(with other: AffineTransform2D) -> AffineTransform2D {
		AffineTransform2D(
			(0..<3).map { row in
				(0..<3).map { column in
					(0..<3).map { i in
						other[row, i] * self[i, column]
					}.reduce(0, +)
				}
			}
		)
	}
}

extension AffineTransform2D {
	public static func translation(x: Double = 0, y: Double = 0) -> AffineTransform2D {
		var transform = identity
		transform[0, 2] = x
		transform[1, 2] = y
		return transform
	}

	public static func translation(_ v: Vector2D) -> AffineTransform2D {
		translation(x: v.x, y: v.y)
	}

	public static func scaling(x: Double = 1, y: Double = 1) -> AffineTransform2D {
		var transform = identity
		transform[0, 0] = x
		transform[1, 1] = y
		return transform
	}

	public static func scaling(_ v: Vector2D) -> AffineTransform2D {
		scaling(x: v.x, y: v.y)
	}

	public static func rotation(_ angle: Angle) -> AffineTransform2D {
		var transform = identity
		transform[0, 0] = cos(angle)
		transform[0, 1] = -sin(angle)
		transform[1, 0] = sin(angle)
		transform[1, 1] = cos(angle)
		return transform
	}

	public static func shearing(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> AffineTransform2D {
		var t = AffineTransform2D.identity
		if axis == .x && otherAxis == .y {
			t[1, 0] = factor
		} else if axis == .y && otherAxis == .x {
			t[0, 1] = factor
		} else {
			preconditionFailure("Shearing requires two distinct axes")
		}
		return t
	}

	public static func shearing(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> AffineTransform2D {
		assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
		let factor = sin(angle) / sin(90° - angle)
		return shearing(axis, along: otherAxis, factor: factor)
	}
}

extension AffineTransform2D {
	public func translated(x: Double = 0, y: Double = 0) -> AffineTransform2D {
		concatenated(with: .translation(x: x, y: y))
	}

	public func translated(_ v: Vector2D) -> AffineTransform2D {
		concatenated(with: .translation(v))
	}

	public func scaled(_ v: Vector2D) -> AffineTransform2D {
		concatenated(with: .scaling(v))
	}

	public func scaled(x: Double = 1, y: Double = 1) -> AffineTransform2D {
		concatenated(with: .scaling(x: x, y: y))
	}

	public func rotated(_ angle: Angle) -> AffineTransform2D {
		concatenated(with: .rotation(angle))
	}

	public func sheared(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> AffineTransform2D {
		concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
	}

	public func sheared(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> AffineTransform2D {
		concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
	}
}

extension AffineTransform2D {
	public var translation: Vector2D {
		Vector2D(
			x: self[0, 2],
			y: self[1, 2]
		)
	}

	public func apply(to point: Vector2D) -> Vector2D {
        let vector = [point.x, point.y, 1.0]

        let newVector = (0...2).map { index -> Double in
            values[index].enumerated().map { column, value in
                value * vector[column]
            }.reduce(0, +)
        }

		return Vector2D(newVector[0], newVector[1])
	}
}

