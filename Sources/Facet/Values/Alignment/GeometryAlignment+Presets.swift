import Foundation

public extension GeometryAlignment {
    /// Represents no alignment, leaving the geometry in its original position.
    static var none: Self { .init(all: nil) }

    /// Centers the geometry along all axes
    static var center: Self { .init(all: .mid) }

    /// Aligns the geometry at its minimum in all axes
    static var min: Self { .init(all: .min) }

    /// Aligns the geometry at its maximum in all axes
    static var max: Self { .init(all: .max) }
}

public extension GeometryAlignment2D {
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
    /// Centers the geometry in the XY plane.
    static let centerXY = Self(x: .mid, y: .mid)

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
