import Foundation

extension Geometry3D {
	public func repeated(along axis: Axis3D, in range: Range<Double>, step: Double) -> Geometry3D {
		let strideBy = stride(from: range.lowerBound, to: range.upperBound, by: step)
		return ForEach(strideBy) { value in
			self.translated(Vector3D(axis: axis, value: value))
		}
	}

	public func repeated(along axis: Axis3D, in range: ClosedRange<Double>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		let strideBy = stride(from: range.lowerBound, through: range.upperBound, by: step)
		return ForEach(strideBy) { value in
			self.translated(Vector3D(axis: axis, value: value))
		}
	}

	public func repeated(around axis: Axis3D, in range: Range<Angle>, step: Angle) -> Geometry3D {
		let strideBy = stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	public func repeated(around axis: Axis3D, in range: ClosedRange<Angle>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		let strideBy = stride(from: range.lowerBound.radians, through: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	public func repeated(around axis: Axis3D, in range: Range<Angle>, count: Int) -> Geometry3D {
		let step = (range.upperBound - range.lowerBound) / Double(count)
		let strideBy = stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(angle: Angle(radians: value), axis: axis)
		}
	}

	public func distributed(at offsets: [Double], along axis: Axis3D) -> Geometry3D {
		ForEach(offsets) { offset in
			self.translated(Vector3D(axis: axis, value: offset))
		}
	}
}


extension Geometry2D {
	public func repeated(along axis: Axis2D, in range: Range<Double>, step: Double) -> Geometry2D {
		let strideBy = stride(from: range.lowerBound, to: range.upperBound, by: step)
		return ForEach(strideBy) { value in
			self.translated(Vector2D(axis: axis, value: value))
		}
	}

	public func repeated(along axis: Axis2D, in range: ClosedRange<Double>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		let strideBy = stride(from: range.lowerBound, through: range.upperBound, by: step)
		return ForEach(strideBy) { value in
			self.translated(Vector2D(axis: axis, value: value))
		}
	}

	public func repeated(in range: Range<Angle>, step: Angle) -> Geometry2D {
		let strideBy = stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(Angle(radians: value))
		}
	}

	public func repeated(in range: ClosedRange<Angle>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count - 1)
		let strideBy = stride(from: range.lowerBound.radians, through: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(Angle(radians: value))
		}
	}

	public func repeated(in range: Range<Angle>, count: Int) -> Geometry2D {
		let step = (range.upperBound - range.lowerBound) / Double(count)
		let strideBy = stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians)
		return ForEach(strideBy) { value in
			self.rotated(Angle(radians: value))
		}
	}

	public func distributed(at offsets: [Double], along axis: Axis2D) -> Geometry2D {
		ForEach(offsets) { offset in
			self.translated(Vector2D(axis: axis, value: offset))
		}
	}
}

