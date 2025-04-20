import Foundation

extension Geometry {
    /// Creates a series of translated copies of this geometry along a specified axis.
    ///
    /// This method duplicates the current geometry and places each copy at a given offset
    /// along the specified axis. It is useful for creating patterns, arrays, or distributed shapes
    /// along one dimension.
    ///
    /// - Parameters:
    ///   - offsets: A sequence of offset values. Each value represents a translation along the given axis.
    ///   - axis: The axis along which to distribute the geometry (e.g., `.x`, `.y`, or `.z` depending on dimensionality).
    /// - Returns: A composite geometry containing all the translated instances of the original.
    ///
    /// Example usage:
    /// ```swift
    /// let peg = Cylinder(radius: 1, height: 5)
    ///     .distributed(at: stride(from: 0, through: 20, by: 5), along: .x)
    /// ```
    /// This creates five cylinders spaced 5 mm apart along the X axis.
    @GeometryBuilder<D>
    public func distributed(at offsets: any Sequence<Double>, along axis: D.Axis) -> D.Geometry {
        for offset in offsets {
            translated(D.Vector(axis, value: offset))
        }
    }

    /// Creates a series of translated copies of this geometry at specified vector offsets.
    ///
    /// This method duplicates the geometry and places each copy at the corresponding offset
    /// defined by a sequence of vectors. Each vector represents a translation along each axis.
    ///
    /// - Parameter offsets: A sequence of translation vectors specifying where each copy should be placed.
    /// - Returns: A composite geometry containing all the translated instances of the original geometry.
    @GeometryBuilder<D>
    public func distributed(at offsets: any Sequence<D.Vector>) -> D.Geometry {
        for offset in offsets {
            translated(offset)
        }
    }

    /// Creates a series of translated copies of this geometry at specified vector offsets.
    ///
    /// This method duplicates the geometry and places each copy at the corresponding offset
    /// defined by a sequence of vectors. Each vector represents a translation along each axis.
    ///
    /// - Parameter offsets: A sequence of translation vectors specifying where each copy should be placed.
    /// - Returns: A composite geometry containing all the translated instances of the original geometry.
    @GeometryBuilder<D>
    public func distributed(at offsets: D.Vector...) -> D.Geometry {
        distributed(at: offsets)
    }
}

extension Geometry2D {    
    /// Creates a series of rotated copies of this geometry at the specified angles.
    ///
    /// This method duplicates the geometry and rotates each copy by a corresponding angle, relative to its original orientation.
    /// It's useful for creating circular patterns, like spokes or radial arrays.
    ///
    /// - Parameter angles: A sequence of angles to apply as rotations around the origin.
    /// - Returns: A composite geometry containing all the rotated instances of the original shape.
    ///
    @GeometryBuilder2D
    public func distributed(at angles: any Sequence<Angle>) -> any Geometry2D {
        for angle in angles {
            rotated(angle)
        }
    }
}

extension Geometry3D {
    /// Creates a series of rotated copies of this geometry at the specified angles around a given axis.
    ///
    /// This method duplicates the geometry and rotates each copy by a corresponding angle around the specified axis.
    /// It's useful for generating radial patterns or repeating geometry in circular arrangements in 3D space.
    ///
    /// - Parameters:
    ///   - angles: A sequence of rotation angles to apply around the axis.
    ///   - axis: The axis to rotate around (e.g. `.x`, `.y`, `.z`).
    /// - Returns: A composite geometry containing all the rotated instances of the original geometry.
    ///
    @GeometryBuilder3D
    public func distributed(at angles: any Sequence<Angle>, around axis: Axis3D) -> any Geometry3D {
        for angle in angles {
            rotated(angle: angle, axis: axis)
        }
    }
}
