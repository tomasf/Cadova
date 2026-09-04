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
        if count > 0 {
            let span = range.upperBound - range.lowerBound
            for i in 0..<count {
                translated(D.Vector(axis, value: range.lowerBound + span * (Double(i) / Double(count))))
            }
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
        if count > 1 {
            let span = range.upperBound - range.lowerBound
            for i in 0..<count {
                translated(D.Vector(axis, value: range.lowerBound + span * (Double(i) / Double(count - 1))))
            }
        } else if count == 1 {
            translated(D.Vector(axis, value: range.lowerBound))
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
    @GeometryBuilder<D>
    public func repeated(along axis: D.Axis, spacing: Double, count: Int) -> D.Geometry {
        if count == 1 {
            self
        } else if count > 0 {
            measuringBounds { _, bounds in
                self.repeated(along: axis, step: bounds.size[axis] + spacing, count: count)
            }
        }
    }

    /// Repeat the geometry along an axis with automatic spacing
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within. The last repetition will occur at the upper bound of this range.
    ///   - minimumSpacing: The minimum spacing between instances, not including the geometry's own size
    ///   - cyclically: When `true`, spacing is distributed as if the range wraps around (e.g., for circular
    ///     arrangements). The last instance will not be placed at the upper bound; instead, there will be
    ///     spacing after it equal to the spacing before the first instance. Defaults to `false`.
    /// - Returns: A new geometry with this geometry repeated
    ///
    /// This method calculates the number of repetitions that can fit within the given range
    /// while maintaining at least the specified minimum spacing between each instance.
    /// The geometry's bounding box is measured to determine its size along the specified axis.
    /// The final spacing is adjusted to fill the available range evenly.
    ///
    public func repeated(along axis: D.Axis, in range: ClosedRange<Double>, minimumSpacing: Double, cyclically: Bool = false) -> D.Geometry {
        // How many instances fit in the range and how far apart to place them, or `nil` if not even one
        // fits. The instance count and the gap count are not the same number, and conflating them is what
        // used to drop the single instance that fits into a range too short for two.
        @Sendable func automaticSpacingPlacement(rangeLength: Double, instanceLength: Double) -> (count: Int, step: Double)? {
            guard rangeLength >= instanceLength else {
                logger.warning("Repeating with a minimum spacing: geometry measuring \(instanceLength) doesn't fit in a range of \(rangeLength). No geometry produced.")
                return nil
            }

            if cyclically {
                // Cyclic spacing leaves a gap after the last instance as well, so every instance costs a
                // full slot of its own length plus the spacing.
                let count = Int(floor(rangeLength / (instanceLength + minimumSpacing)))
                guard count > 0 else {
                    logger.warning("Repeating cyclically with a minimum spacing: a range of \(rangeLength) has no room for an instance and its trailing gap. No geometry produced.")
                    return nil
                }
                return (count, rangeLength / Double(count))

            } else {
                // The first instance takes up its own length; what remains is what further instances have
                // to fit into, each costing its length plus the spacing. That count is the number of gaps,
                // so there is one more instance than gaps.
                let availableLength = rangeLength - instanceLength
                let count = Int(floor(availableLength / (instanceLength + minimumSpacing))) + 1
                return (count, count > 1 ? availableLength / Double(count - 1) : 0)
            }
        }

        return measuringBounds { _, bounds in
            let placement = automaticSpacingPlacement(
                rangeLength: range.upperBound - range.lowerBound,
                instanceLength: bounds.size[axis]
            )

            if let placement {
                self.repeated(along: axis, step: placement.step, count: placement.count)
                    .translated(D.Vector(axis, value: range.lowerBound))
            }
        }
    }
}
