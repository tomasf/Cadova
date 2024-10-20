import Foundation

/// The profile of an edge
public struct EdgeProfile: Sendable {
    private let profileShape: any EdgeProfileShape

    internal init(_ profileShape: any EdgeProfileShape) {
        self.profileShape = profileShape
    }

    /// Generates a shape for edge modification, suitable for extrusion along an edge to customize its profile.
    ///
    /// This method creates a 2D shape, designed for altering edges by extruding this shape along the edge's path. The extruded shape can be utilized to modify a 3D object’s edges by either adding to or subtracting from it:
    /// - For exterior edges, subtract the extruded shape to mitigate sharpness or create a beveled effect.
    /// - For interior edges, add the extruded shape to expand it.
    ///
    /// - Parameter angle: specifies the edge's angle. This makes the shape align with the geometry of the edge being modified.
    public func shape(angle: Angle = 90°) -> any Geometry2D {
        profileShape.shape(angle: angle)
    }

    public var width: Double { profileShape.size.x }
    public var height: Double { profileShape.size.y }
}

public extension EdgeProfile {
    /// Represents an edge modified to be rounded with an elliptic shape
    ///   - width: The horizontal distance from the original edge to the fillet's farthest point, determining the fillet's depth.
    ///   - height: The vertical height from the base of the edge to the top of the fillet.
    static func fillet(width: Double, height: Double) -> EdgeProfile {
        .init(Fillet(width: width, height: height))
    }

    /// Represents an edge modified to be rounded.
    /// - Parameter radius: The radius of the curvature applied to the edge, determining the degree of roundness.
    static func fillet(radius: Double) -> EdgeProfile {
        .fillet(width: radius, height: radius)
    }
}

public extension EdgeProfile {
    /// Represents an edge that is chamfered, creating a beveled effect by cutting off the edge at a flat angle.
    /// - Parameters:
    ///   - width: The horizontal distance from the original edge to the chamfer's farthest point, determining the chamfer's depth.
    ///   - height: The vertical height from the base of the edge to the top of the chamfer.
    static func chamfer(width: Double, height: Double) -> EdgeProfile {
        .init(Chamfer(width: width, height: height))
    }

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

public extension EdgeProfile {
    /// Represents an edge that combines a rounded fillet with a straight chamfer near the top or bottom.
    /// Useful for 3D printing where bottom edges can't have too much overhang.
    /// - Parameters:
    ///   - radius: The radius of the curvature applied to the edge.
    ///   - overhang: The angle of the straight chamfer near the top or bottom.
    static func chamferedFillet(radius: Double, overhang: Angle = 45°) -> EdgeProfile {
        .init(ChamferedFillet(radius: radius, overhang: overhang))
    }
}

public extension EdgeProfile {
    /// Methods for building an extruded shape with modified edges
    enum Method {
        /// Divide the extrusion into distinct layers with a given thickness. While less elegant and more expensive to render, it is suitable for non-convex shapes. Layers work well for 3D printing, as the printing process inherently occurs in layers.
        case layered (height: Double)
        /// Create a smooth, non-layered shape. It is often computationally less intensive and results in a more aesthetically pleasing form but only works as expected for convex shapes.
        case convexHull
    }
}

internal extension EdgeProfile {
    func mask(shape: any Geometry2D, extrusionHeight: Double, method: EdgeProfile.Method) -> any Geometry3D {
        profileShape.mask(shape: shape, extrusionHeight: extrusionHeight, method: method)
    }

    func negativeMask(shape: any Geometry2D, method: EdgeProfile.Method) -> any Geometry3D {
        shape
            .offset(amount: 0.01, style: .round)
            .extruded(height: height + 0.01)
            .subtracting {
                profileShape.mask(shape: shape, extrusionHeight: height, method: method)
            }
            .translated(z: -height)
    }
}
