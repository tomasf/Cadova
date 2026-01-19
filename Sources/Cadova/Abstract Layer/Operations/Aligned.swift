import Foundation

public extension Geometry {
    /// Aligns the geometry according to specified alignment criteria.
    ///
    /// This method adjusts the position of the geometry so that its bounding box aligns to the coordinate system's
    /// origin. Usage of multiple alignment parameters allows for compound alignments, such as aligning to the center
    /// along the X-axis and to the top along the Y-axis.
    ///
    /// - Parameter alignment: A list of alignment criteria specifying how the geometry should be aligned. Each
    ///   alignment option targets a specific axis. If more than one alignment is passed for the same axis, the last one
    ///   is used.
    /// - Returns: A new geometry that is the result of applying the specified alignments to the original geometry.
    ///
    /// Example:
    /// ```
    /// let square = Rectangle(x: 20, y: 10)
    ///     .aligned(at: .centerX, .bottom)
    /// ```
    /// This example centers the square along the X-axis and aligns its bottom edge with the Y=0 line.
    /// 
    func aligned(at alignment: D.Alignment...) -> D.Geometry {
        measuringBounds { child, bounds in
            child.translated(bounds.translation(for: .init(merging: alignment)))
        }
    }

    /// Temporarily aligns this geometry while performing operations, then restores its original position.
    ///
    /// This helper aligns the geometry according to the provided alignment options, evaluates `operations` in that
    /// aligned coordinate space, and then applies the inverse translation to return the result to its original space.
    ///
    /// - Parameters:
    ///   - alignment: A list of alignment criteria specifying how the geometry should be aligned before evaluating
    ///     `operations`.
    ///   - operations: A builder that produces geometry to be evaluated in the aligned space.
    /// - Returns: The resulting geometry mapped back into the original coordinate space.
    ///
    /// Example:
    /// ```
    /// Rectangle(x: 20, y: 10)
    ///     .whileAligned(at: .center) {
    ///         $0.rotated(45°)
    ///     }
    /// ```
    ///
    func whileAligned(
        at alignment: D.Alignment...,
        @GeometryBuilder<D> do operations: @Sendable @escaping (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        measuringBounds { child, bounds in
            let translation = bounds.translation(for: .init(merging: alignment))
            return operations(child.translated(translation)).translated(-translation)
        }
    }
}
