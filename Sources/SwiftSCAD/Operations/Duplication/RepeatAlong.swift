import Foundation

extension Geometry2D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
    public func repeated(along axis: Axis2D, in range: Range<Double>, step: Double) -> any Geometry2D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
    public func repeated(along axis: Axis2D, in range: Range<Double>, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
    public func repeated(along axis: Axis2D, in range: ClosedRange<Double>, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            translated(Vector2D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - step: The offset between each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
    public func repeated(along axis: Axis2D, step: Double, count: Int) -> any Geometry2D {
        for i in 0..<count {
            self.translated(.init(axis, value: Double(i) * step))
        }
    }
}

extension Geometry2D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - spacing: The spacing between the measured bounding box of each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    public func repeated(along axis: Axis2D, spacing: Double, count: Int) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            let step = bounds.requireNonNil().size[axis] + spacing
            geometry.repeated(along: axis, step: step, count: count)
        }
    }

    public func repeated(along axis: Axis2D, in range: ClosedRange<Double>, minimumSpacing: Double) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            let boundsLength = bounds.requireNonNil().size[axis]
            let availableLength = range.upperBound - range.lowerBound - boundsLength
            let count = Int(floor(availableLength / (boundsLength + minimumSpacing)))
            let step = availableLength / Double(count)
            geometry.repeated(along: axis, step: step, count: count + 1)
        }
    }
}

extension Geometry3D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder3D
    public func repeated(along axis: Axis3D, in range: Range<Double>, step: Double) -> any Geometry3D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder3D
    public func repeated(along axis: Axis3D, in range: Range<Double>, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder3D
    public func repeated(along axis: Axis3D, in range: ClosedRange<Double>, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            translated(Vector3D(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - step: The offset between each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder3D
    public func repeated(along axis: Axis3D, step: Double, count: Int) -> any Geometry3D {
        for i in 0..<count {
            self.translated(.init(axis, value: Double(i) * step))
        }
    }
}

extension Geometry3D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - spacing: The spacing between the measured bounding box of each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    public func repeated(along axis: Axis3D, spacing: Double, count: Int) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            let boundsLength = bounds.requireNonNil().size[axis]
            let step = boundsLength + spacing
            geometry.repeated(along: axis, step: step, count: count)
        }
    }

    public func repeated(along axis: Axis3D, in range: ClosedRange<Double>, minimumSpacing: Double) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            let boundsLength = bounds.requireNonNil().size[axis]
            let availableLength = range.upperBound - range.lowerBound - boundsLength
            let count = Int(floor(availableLength / (boundsLength + minimumSpacing)))
            let step = availableLength / Double(count)
            geometry.repeated(along: axis, step: step, count: max(count + 1, 1))
        }
    }
}
