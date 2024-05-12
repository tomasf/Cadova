import Foundation

extension Geometry2D {
    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within
    ///   - step: The angular distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(in range: Range<Angle> = 0°..<360°, step: Angle) -> any Geometry2D {
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(Angle(radians: value))
        }
    }

    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(in range: Range<Angle> = 0°..<360°, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(Angle(radians: value))
        }
    }

    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D
    public func repeated(in range: ClosedRange<Angle>, count: Int) -> any Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            rotated(value)
        }
    }
}

extension Geometry3D {
    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within
    ///   - step: The angular distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(around axis: Axis3D, in range: Range<Angle> = 0°..<360°, step: Angle) -> any Geometry3D {
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(angle: Angle(radians: value), axis: axis)
        }
    }

    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(around axis: Axis3D, in range: Range<Angle> = 0°..<360°, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            rotated(angle: value, axis: axis)
        }
    }

    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D
    public func repeated(around axis: Axis3D, in range: ClosedRange<Angle>, count: Int) -> any Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            rotated(angle: value, axis: axis)
        }
    }
}
