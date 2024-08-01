import Foundation

public extension Geometry2D {
    /// Extrudes a 2D geometry to form a 3D shape with chamfers or fillets along the top and/or bottom edges
    ///
    /// This method allows you to create a 3D shape by extruding the 2D geometry.
    /// The method of extrusion can be selected based on the desired characteristics
    /// of the resulting shape.
    ///
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - topEdge: The profile of the top edge.
    ///   - bottomEdge: The profile of the bottom edge.
    ///   - method: The method of extrusion, either `.layered(thickness:)` or `.convexHull`.
    ///     - `.layered`: This method divides the extrusion into distinct layers with a given thickness. While less elegant and more expensive to render, it is suitable for non-convex shapes. Layers work well for 3D printing, as the printing process inherently occurs in layers.
    ///     - `.convexHull`: This method creates a smooth, non-layered shape. It is often computationally less intensive and results in a more aesthetically pleasing form but only works as expected for convex shapes.
    /// - Returns: The extruded 3D geometry.

    func extruded(height: Double, topEdge: EdgeProfile?, bottomEdge: EdgeProfile?, method: EdgeProfile.Method) -> any Geometry3D {
        var shape = extruded(height: height)
        if let topEdge {
            shape = shape.intersection(topEdge.mask(shape: self, extrusionHeight: height, method: method))
        }
        if let bottomEdge {
            shape = shape.intersection {
                bottomEdge.mask(shape: self, extrusionHeight: height, method: method)
                    .flipped(along: .z)
                    .translated(z: height)
            }
        }
        return shape
    }

    /// See ``extruded(height:topEdge:bottomEdge:method:)``
    func extruded(height: Double, topEdge: EdgeProfile, method: EdgeProfile.Method) -> any Geometry3D {
        extruded(height: height, topEdge: topEdge, bottomEdge: nil, method: method)
    }

    /// See ``extruded(height:topEdge:bottomEdge:method:)``
    func extruded(height: Double, bottomEdge: EdgeProfile, method: EdgeProfile.Method) -> any Geometry3D {
        extruded(height: height, topEdge: nil, bottomEdge: bottomEdge, method: method)
    }
}
