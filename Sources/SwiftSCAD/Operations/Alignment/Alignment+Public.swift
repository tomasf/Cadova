import Foundation

public extension Geometry2D {
    /// Aligns the geometry according to specified alignment criteria.
    ///
    /// This method adjusts the position of the geometry so that its bounding box aligns to the coordinate system's origin. Usage of multiple alignment parameters allows for compound alignments, such as aligning to the center along the X-axis and to the top along the Y-axis.
    ///
    /// - Parameter alignment: A list of alignment criteria specifying how the geometry should be aligned. Each alignment option targets a specific axis. If more than one alignment is passed for the same axis, the last one is used.
    /// - Returns: A new geometry that is the result of applying the specified alignments to the original geometry.
    ///
    /// Example:
    /// ```
    /// let square = Rectangle([10, 10])
    ///     .aligned(at: .centerX, .bottom)
    /// ```
    /// This example centers the square along the X-axis and aligns its bottom edge with the Y=0 line.
    func aligned(at alignment: GeometryAlignment2D...) -> any Geometry2D {
        Align2D(content: self, alignment: .init(merging: alignment))
    }
}

public extension Geometry3D {
    /// Aligns the geometry according to specified alignment criteria.
    ///
    /// This method adjusts the position of the geometry so that its bounding box aligns to the coordinate system's origin. Usage of multiple alignment parameters allows for compound alignments, such as aligning to the center along the X-axis and to the top along the Z-axis.
    ///
    /// - Parameter alignment: A variable list of alignment criteria specifying how the geometry should be aligned. Each alignment option targets a specific axis. If more than one alignment is passed for the same axis, the last one is used.
    /// - Returns: A new geometry that is the result of applying the specified alignments to the original geometry.
    ///
    /// Example:
    /// ```
    /// let box = Box([10, 10, 5])
    ///     .aligned(at: .centerX, .bottom)
    /// ```
    /// This example centers the square along the X-axis and aligns its bottom edge with the Z=0 line.
    func aligned(at alignment: GeometryAlignment3D...) -> any Geometry3D {
        Align3D(content: self, alignment: .init(merging: alignment))
    }
}

public extension GeometryAlignment2D {
    /// Represents no alignment, leaving the geometry in its original position.
    static let none = Self()

    /// Centers the geometry both horizontally and vertically.
    static let center = Self(x: .mid, y: .mid)

    /// Aligns the geometry at its origin
    static let origin = Self(x: .min, y: .min)

    /// Aligns the geometry's minimum X boundary to the coordinate system's origin (X = 0).
    static let minX = Self(x: .min)
    /// Centers the geometry horizontally.
    static let centerX = Self(x: .mid)
    /// Aligns the geometry's maximum X boundary to the coordinate system's origin (X = 0).
    static let maxX = Self(x: .max)

    /// Alias for `minX`, aligning the geometry to the left.
    static let left = minX
    /// Alias for `maxX`, aligning the geometry to the right.
    static let right = maxX

    /// Aligns the geometry's minimum Y boundary to the coordinate system's origin (Y = 0).
    static let minY = Self(y: .min)
    /// Centers the geometry vertically.
    static let centerY = Self(y: .mid)
    /// Aligns the geometry's maximum Y boundary to the coordinate system's origin (Y = 0).
    static let maxY = Self(y: .max)

    /// Alias for `maxY`, aligning the geometry to the top.
    static let top = maxY
    /// Alias for `minY`, aligning the geometry to the bottom.
    static let bottom = minY
}

public extension GeometryAlignment3D {
    /// Represents no alignment, maintaining the geometry's original position.
    static let none = Self()

    /// Centers the geometry in all three dimensions.
    static let center = Self(x: .mid, y: .mid, z: .mid)
    /// Centers the geometry in the XY plane.
    static let centerXY = Self(x: .mid, y: .mid)

    /// Aligns the geometry at its origin
    static let origin = Self(x: .min, y: .min, z: .min)

    /// Aligns the geometry's minimum X boundary to the coordinate system's origin (X = 0).
    static let minX = Self(x: .min)
    /// Centers the geometry along the X-axis.
    static let centerX = Self(x: .mid)
    /// Aligns the geometry's maximum X boundary to the coordinate system's origin (X = 0).
    static let maxX = Self(x: .max)

    /// Alias for `minX`, aligning the geometry to the left.
    static let left = minX
    /// Alias for `maxX`, aligning the geometry to the right.
    static let right = maxX

    /// Aligns the geometry's minimum Y boundary to the coordinate system's origin (Y = 0).
    static let minY = Self(y: .min)
    /// Centers the geometry along the Y-axis.
    static let centerY = Self(y: .mid)
    /// Aligns the geometry's maximum Y boundary to the coordinate system's origin (Y = 0).
    static let maxY = Self(y: .max)

    /// Alias for `maxY`, positioning the geometry at the back.
    static let back = maxY
    /// Alias for `minY`, positioning the geometry at the front.
    static let front = minY

    /// Aligns the geometry's minimum Z boundary to the coordinate system's origin (Z = 0).
    static let minZ = Self(z: .min)
    /// Centers the geometry along the Z-axis.
    static let centerZ = Self(z: .mid)
    /// Aligns the geometry's maximum Z boundary to the coordinate system's origin (Z = 0).
    static let maxZ = Self(z: .max)

    /// Alias for `maxZ`, aligning the geometry to the top.
    static let top = maxZ
    /// Alias for `minZ`, aligning the geometry to the bottom.
    static let bottom = minZ
}
