import Foundation

extension Geometry3D {
	@UnionBuilder public func repeated(along axis: Axis3D, in range: Range<Double>, step: Double) -> Geometry3D {
		for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
			translated(Vector3D(axis: axis, value: value))
		}
	}

	@UnionBuilder public func repeated(along axis: Axis3D, in range: ClosedRange<Double>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
			translated(Vector3D(axis: axis, value: value))
		}
	}

	@UnionBuilder public func repeated(around axis: Axis3D, in range: Range<Angle>, step: Angle) -> Geometry3D {
		for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
			rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	@UnionBuilder public func repeated(around axis: Axis3D, in range: ClosedRange<Angle>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		for value in stride(from: range.lowerBound.radians, through: range.upperBound.radians, by: step.radians) {
			rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	@UnionBuilder public func repeated(around axis: Axis3D, in range: Range<Angle>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count)
		for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
			rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	@UnionBuilder public func distributed(at offsets: [Double], along axis: Axis3D) -> Geometry3D {
		for offset in offsets {
			translated(Vector3D(axis: axis, value: offset))
		}
	}

	@UnionBuilder public func distributed(at angles: [Angle], around axis: Axis3D) -> Geometry3D {
		for angle in angles {
			rotated(angle: angle, axis: axis)
		}
	}
}


extension Geometry2D {
	@UnionBuilder public func repeated(along axis: Axis2D, in range: Range<Double>, step: Double) -> Geometry2D {
		for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
			translated(Vector2D(axis: axis, value: value))
		}
	}

	@UnionBuilder public func repeated(along axis: Axis2D, in range: ClosedRange<Double>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
			translated(Vector2D(axis: axis, value: value))
		}
	}

	@UnionBuilder public func repeated(in range: Range<Angle>, step: Angle) -> Geometry2D {
		for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
			rotated(Angle(radians: value))
		}
	}

	@UnionBuilder public func repeated(in range: ClosedRange<Angle>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		for value in stride(from: range.lowerBound.radians, through: range.upperBound.radians, by: step.radians) {
			rotated(Angle(radians: value))
		}
	}

	@UnionBuilder public func repeated(in range: Range<Angle>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count)
		for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
			rotated(Angle(radians: value))
		}
	}

	@UnionBuilder public func distributed(at offsets: [Double], along axis: Axis2D) -> Geometry2D {
		for offset in offsets {
			translated(Vector2D(axis: axis, value: offset))
		}
	}

	@UnionBuilder public func distributed(at angles: [Angle]) -> Geometry2D {
		for angle in angles {
			rotated(angle)
		}
	}
}

