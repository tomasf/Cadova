import Foundation

extension Geometry {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated
    ///
    @GeometryBuilder<D>
    public func repeated(along axis: D.Axis, in range: Range<Double>, step: Double) -> D.Geometry {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(D.Vector(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated
    ///
    @GeometryBuilder<D>
    public func repeated(along axis: D.Axis, in range: Range<Double>, count: Int) -> D.Geometry {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(D.Vector(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this
    ///     range.
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated
    ///
    @GeometryBuilder<D>
    public func repeated(along axis: D.Axis, in range: ClosedRange<Double>, count: Int) -> D.Geometry {
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        for value in stride(from: range.lowerBound, through: range.upperBound, by: step) {
            translated(D.Vector(axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - step: The offset between each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated
    ///
    @GeometryBuilder<D>
    public func repeated(along axis: D.Axis, step: Double, count: Int) -> D.Geometry {
        for i in 0..<count {
            self.translated(.init(axis, value: Double(i) * step))
        }
    }
}

extension Geometry {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - spacing: The spacing between the measured bounding box of each instance
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated
    ///
    public func repeated(along axis: D.Axis, spacing: Double, count: Int) -> D.Geometry {
        measuringBounds { _, bounds in
            self.repeated(along: axis, step: bounds.size[axis] + spacing, count: count)
        }
    }

    /// Repeat the geometry along an axis with automatic spacing
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - minimumSpacing: The minimum spacing between instances, not including the geometry’s own size
    /// - Returns: A new geometry with this geometry repeated
    ///
    /// This method calculates the number of repetitions that can fit within the given range
    /// while maintaining at least the specified minimum spacing between each instance.
    /// The geometry’s bounding box is measured to determine its size along the specified axis.
    /// The final spacing is adjusted to fill the available range evenly.
    /// 
    public func repeated(along axis: D.Axis, in range: ClosedRange<Double>, minimumSpacing: Double) -> D.Geometry {
        measuringBounds { _, bounds in
            let boundsLength = bounds.size[axis]
            let availableLength = range.upperBound - range.lowerBound - boundsLength
            let count = Int(floor(availableLength / (boundsLength + minimumSpacing)))
            let step = availableLength / Double(count)
            self.repeated(along: axis, step: step, count: count + 1)
        }
    }
}
