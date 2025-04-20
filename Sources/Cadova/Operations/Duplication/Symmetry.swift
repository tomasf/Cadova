import Foundation

public extension Geometry2D {
    /// Creates mirrored copies of this geometry across the specified axes, forming a symmetrical pattern.
    ///
    /// This method reflects the geometry over the provided axes.  For each axis included in the `axes`
    /// set, a mirrored version is generated across that axis. The resulting output includes the original
    /// geometry and all its mirrored counterparts.
    ///
    /// - Parameter axes: A set of axes (`.x`, `.y`) over which to mirror the geometry.
    /// - Returns: A composite geometry containing the original and all mirrored variants.
    ///

    @GeometryBuilder2D
    func symmetry(over axes: Axes2D) -> any Geometry2D {
        for xs in axes.contains(.x) ? [1.0, -1.0] : [1.0] {
            for ys in axes.contains(.y) ? [1.0, -1.0] : [1.0] {
                scaled(x: xs, y: ys)
            }
        }
    }
}

public extension Geometry3D {
    /// Creates mirrored copies of this geometry across the specified axes, forming a symmetrical pattern.
    ///
    /// This method reflects the geometry over the provided axes.  For each axis included in the `axes`
    /// set, a mirrored version is generated across that axis. The resulting output includes the original
    /// geometry and all its mirrored counterparts.
    ///
    /// - Parameter axes: A set of axes (`.x`, `.y`, `.z`) over which to mirror the geometry.
    /// - Returns: A composite geometry containing the original and all mirrored variants.
    ///
    @GeometryBuilder3D
    func symmetry(over axes: Axes3D) -> any Geometry3D {
        for xs in axes.contains(.x) ? [1.0, -1.0] : [1.0] {
            for ys in axes.contains(.y) ? [1.0, -1.0] : [1.0] {
                for zs in axes.contains(.z) ? [1.0, -1.0] : [1.0] {
                    scaled(x: xs, y: ys, z: zs)
                }
            }
        }
    }
}
