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
        measuring { child, measurements in
            child.translated(measurements.boundingBox?.translation(for: .init(merging: alignment)) ?? .zero)
        }
    }
}
