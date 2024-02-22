import Foundation

/// The shape of the edge of an extruded shape
public enum EdgeProfile: Equatable {
    /// A sharp edge without modification
    case sharp
    /// A rounded edge
    case fillet (radius: Double)
    /// A flat chamfered edge
    /// - Parameters:
    ///   - width: The depth of the chamfer in the X/Y axes
    ///   - topEdge: The depth of the chamfer in the Z axis
    case chamfer (width: Double, height: Double)

    /// Methods for building an extruded shape with modified edges
    public enum Method {
        /// Divide the extrusion into distinct layers with a given thickness. While less elegant and more expensive to render, it is suitable for non-convex shapes. Layers work well for 3D printing, as the printing process inherently occurs in layers.
        case layered (height: Double)
        /// Create a smooth, non-layered shape. It is often computationally less intensive and results in a more aesthetically pleasing form but only works as expected for convex shapes.
        case convexHull
    }
}

public extension EdgeProfile {
    /// A 45° chamfered edge
    static func chamfer(size: Double) -> EdgeProfile {
        .chamfer(width: size, height: size)
    }

    /// A chamfered edge with a given width and angle
    /// - Parameters:
    ///   - width: The depth of the chamfer in the X/Y axes
    ///   - angle: An angle between 0° and 90°, measured from the top of the extrusion
    static func chamfer(width: Double, angle: Angle) -> EdgeProfile {
        assert((0°..<90°).contains(angle), "Chamfer angle must be between 0° and 90°")
        return .chamfer(width: width, height: width * tan(angle))
    }

    /// A chamfered edge with a given height and angle
    /// - Parameters:
    ///   - height: The depth of the chamfer in the Z axis
    ///   - angle: An angle between 0° and 90°, measured from the top of the extrusion
    static func chamfer(height: Double, angle: Angle) -> EdgeProfile {
        assert((0°..<90°).contains(angle), "Chamfer angle must be between 0° and 90°")
        return .chamfer(width: height / tan(angle), height: height)
    }
}

public extension Geometry2D {

    /// Extrudes a 2D geometry into a 3D shape with chamfers or fillets along the top and/or bottom edges
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

    func extruded(height: Double, topEdge: EdgeProfile = .sharp, bottomEdge: EdgeProfile = .sharp, method: EdgeProfile.Method) -> any Geometry3D {
        extruded(height: height)
            .intersection {
                if topEdge != .sharp {
                    edgeMask(height: height, edgeProfile: topEdge, method: method)
                }
            }
            .intersection {
                if bottomEdge != .sharp {
                    edgeMask(height: height, edgeProfile: bottomEdge, method: method)
                        .flipped(along: .z)
                        .translated(z: height)
                }
            }
    }
}

private extension Geometry2D {
    func edgeMask(height: Double, edgeProfile: EdgeProfile, method: EdgeProfile.Method) -> any Geometry3D {
        switch edgeProfile {
        case .sharp:
            extruded(height: height)
        case .fillet (let radius):
            filletEdgeMask(height: height, topRadius: radius, method: method)
        case .chamfer (let chamferWidth, let chamferHeight):
            chamferEdgeMask(height: height, chamferWidth: chamferWidth, chamferHeight: chamferHeight, method: method)
        }
    }
}
