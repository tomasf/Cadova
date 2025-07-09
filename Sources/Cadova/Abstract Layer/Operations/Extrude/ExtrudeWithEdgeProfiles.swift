import Foundation

public extension Geometry2D {
    /// Extrudes a 2D geometry to form a 3D shape with profiled edges (such as chamfers or fillets)
    /// on the top and/or bottom sides
    ///
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - topEdge: The profile of the top edge.
    ///   - bottomEdge: The profile of the bottom edge.
    /// - Returns: The extruded 3D geometry.
    ///
    func extruded(height: Double, topEdge: EdgeProfile?, bottomEdge: EdgeProfile?) -> any Geometry3D {
        var geometry = extruded(height: height)
        if let topEdge {
            geometry = geometry.applyingEdgeProfile(topEdge, to: .top, type: .subtractive)
        }
        if let bottomEdge {
            geometry = geometry.applyingEdgeProfile(bottomEdge, to: .bottom, type: .subtractive)
        }
        return geometry
    }

    /// See ``extruded(height:topEdge:bottomEdge:)``
    func extruded(height: Double, topEdge: EdgeProfile) -> any Geometry3D {
        extruded(height: height, topEdge: topEdge, bottomEdge: nil)
    }

    /// See ``extruded(height:topEdge:bottomEdge:)``
    func extruded(height: Double, bottomEdge: EdgeProfile) -> any Geometry3D {
        extruded(height: height, topEdge: nil, bottomEdge: bottomEdge)
    }
}
