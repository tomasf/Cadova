import Foundation

public extension Geometry2D {
    /// Extrudes the current 2D geometry, forming a 3D convex hull with a specified top shape.
    ///
    /// This function takes the receiver 2D geometry and creates a convex 3D hull that connects
    /// it to the provided top shape. The resulting shape is a 3D object that smoothly connects
    /// the base and top geometries.
    ///
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - topShape: The 2D geometry to use as the top shape.
    /// - Returns: A 3D convex hull connecting the base and top geometries.
    func extrudedHull(height: Double, to topShape: any Geometry2D) -> any Geometry3D {
        let sliceHeight = 0.001

        return extruded(height: sliceHeight)
            .adding {
                topShape
                    .extruded(height: sliceHeight)
                    .translated(z: height - sliceHeight)
            }
            .convexHull()
    }

    /// Extrudes the current 2D geometry, forming a 3D convex hull with a specified top shape.
    ///
    /// This function takes the receiver 2D geometry and creates a convex 3D hull that connects
    /// it to the provided top shape. The resulting shape is a 3D object that smoothly connects
    /// the base and top geometries.
    ///
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - topShape: The 2D geometry to use as the top shape.
    /// - Returns: A 3D convex hull connecting the base and top geometries.
    func extrudedHull(height: Double, @UnionBuilder2D to topShape: () -> any Geometry2D) -> any Geometry3D {
        extrudedHull(height: height, to: topShape())
    }
}
