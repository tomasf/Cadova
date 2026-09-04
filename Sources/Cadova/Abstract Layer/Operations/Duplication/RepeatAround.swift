import Foundation

extension Geometry2D {
    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within
    ///   - step: The angular distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
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

    @GeometryBuilder2D
    public func repeated(in range: Range<Angle> = 0°..<360°, count: Int) -> any Geometry2D {
        if count > 0 {
            let sweep = range.upperBound - range.lowerBound
            for i in 0..<count {
                rotated(range.lowerBound + sweep * (Double(i) / Double(count)))
            }
        }
    }

    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within. The last repetition will occur at the upper bound of this
    ///     range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder2D
    public func repeated(in range: ClosedRange<Angle>, count: Int) -> any Geometry2D {
        if count > 1 {
            let sweep = range.upperBound - range.lowerBound
            for i in 0..<count {
                rotated(range.lowerBound + sweep * (Double(i) / Double(count - 1)))
            }
        } else if count == 1 {
            rotated(range.lowerBound)
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

    @GeometryBuilder3D
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

    @GeometryBuilder3D
    public func repeated(around axis: Axis3D, in range: Range<Angle> = 0°..<360°, count: Int) -> any Geometry3D {
        if count > 0 {
            let sweep = range.upperBound - range.lowerBound
            for i in 0..<count {
                rotated(angle: range.lowerBound + sweep * (Double(i) / Double(count)), axis: axis)
            }
        }
    }

    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within. The last repetition will occur at the upper bound of this range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @GeometryBuilder3D
    public func repeated(around axis: Axis3D, in range: ClosedRange<Angle>, count: Int) -> any Geometry3D {
        if count > 1 {
            let sweep = range.upperBound - range.lowerBound
            for i in 0..<count {
                rotated(angle: range.lowerBound + sweep * (Double(i) / Double(count - 1)), axis: axis)
            }
        } else if count == 1 {
            rotated(angle: range.lowerBound, axis: axis)
        }
    }
}
