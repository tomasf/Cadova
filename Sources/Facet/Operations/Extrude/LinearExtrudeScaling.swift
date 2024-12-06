import Foundation

public extension Geometry2D {
    /// Extrudes the 2D geometry into a 3D shape along the Z-axis, allowing for varying scaling for the other axes along the extrusion.
    ///
    /// - Parameters:
    ///   - height: The total height of the extrusion along the Z-axis.
    ///   - scaling: A closure that provides a `Double` for scaling the X and Y axes for each Z position in the extrusion. This allows the shape to dynamically change its size at each slice.
    ///
    /// - Returns: A 3D geometry created by extruding the 2D geometry with customized scaling applied at each Z position, allowing for flexible shaping along the extrusion path.
    ///
    func extruded(height: Double, scaling: @escaping (_ z: Double) -> Double) -> any Geometry3D {
        extruded(height: height) {
            Vector2D.init(scaling($0))
        }
    }

    /// Extrudes the 2D geometry into a 3D shape along the Z-axis, allowing for varying scaling along both the X and Y axes along the extrusion.
    ///
    /// - Parameters:
    ///   - height: The total height of the extrusion along the Z-axis.
    ///   - scaling: A closure that provides a `Vector2D` with separate scaling factors for X and Y axes for each Z position in the extrusion. This allows the shape to dynamically change its X and Y dimensions at each slice.
    ///
    /// - Returns: A 3D geometry created by extruding the 2D geometry with customized scaling applied at each Z position, allowing for flexible shaping along the extrusion path.
    ///
    @GeometryBuilder3D
    func extruded(height: Double, scaling: @escaping (_ z: Double) -> Vector2D) -> any Geometry3D {
        readEnvironment { e in
            let sliceCount = e.facets.facetCount(length: height)
            let sliceHeight = height / Double(sliceCount)
            let safe: (Vector2D) -> Vector2D = { .max($0, [0.0001, 0.0001]) }

            for (fromSlice, toSlice) in (0...sliceCount).paired() {
                let fromScale = scaling(sliceHeight * Double(fromSlice))
                let toScale = scaling(sliceHeight * Double(toSlice))
                let relativeScale = safe(toScale) / safe(fromScale)
                self
                    .scaled(fromScale)
                    .extruded(height: sliceHeight, scale: relativeScale)
                    .translated(z: sliceHeight * Double(fromSlice))
            }
        }
    }
}
