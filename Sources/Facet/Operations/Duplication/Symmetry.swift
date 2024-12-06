import Foundation

public extension Geometry3D {
    /// Repeat this geometry mirrored across the provided axes
    /// - Parameter axes: The axes to use
    
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

public extension Geometry2D {
    /// Repeat this geometry mirrored across the provided axes
    /// - Parameter axes: The axes to use

    @GeometryBuilder2D
    func symmetry(over axes: Axes2D) -> any Geometry2D {
        for xs in axes.contains(.x) ? [1.0, -1.0] : [1.0] {
            for ys in axes.contains(.y) ? [1.0, -1.0] : [1.0] {
                scaled(x: xs, y: ys)
            }
        }
    }
}
