import Foundation

extension Geometry2D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(along axis: Axis2D, in range: Range<Double>, step: Double) -> any Geometry2D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(along axis: Axis2D, in range: Range<Double>, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(along axis: Axis2D, in range: ClosedRange<Double>, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            translated(Vector2D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - step: The offset between each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(along axis: Axis2D, step: Double, count: Int) -> any Geometry2D {
        for i in 0..<count {
            self.translated(.init(axis: axis, value: Double(i) * step))
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

    @UnionBuilder3D
    public func repeated(along axis: Axis3D, in range: Range<Double>, step: Double) -> any Geometry3D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(along axis: Axis3D, in range: Range<Double>, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(along axis: Axis3D, in range: ClosedRange<Double>, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            translated(Vector3D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - step: The offset between each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(along axis: Axis3D, step: Double, count: Int) -> any Geometry3D {
        for i in 0..<count {
            self.translated(.init(axis: axis, value: Double(i) * step))
        }
    }
}
