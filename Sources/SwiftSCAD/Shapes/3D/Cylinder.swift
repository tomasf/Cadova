import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: LeafGeometry3D {
    let height: Double
    let diameter: Double
    let topDiameter: Double?
    let centerZ: Bool

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder
    ///   - centerZ: If true, center the cylinder along the Z axis

    public init(diameter: Double, height: Double, centerZ: Bool = false) {
        self.diameter = diameter
        self.topDiameter = nil
        self.height = height
        self.centerZ = centerZ
    }

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder
    ///   - centerZ: If true, center the cylinder along the Z axis

    public init(radius: Double, height: Double, centerZ: Bool = false) {
        self.diameter = radius * 2
        self.topDiameter = nil
        self.height = height
        self.centerZ = centerZ
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom
    ///   - centerZ: If true, center the cylinder along the Z axis

    public init(bottomDiameter: Double, topDiameter: Double, height: Double, centerZ: Bool = false) {
        self.diameter = bottomDiameter
        self.topDiameter = topDiameter
        self.height = height
        self.centerZ = centerZ
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom radii)
    /// - Parameters:
    ///   - bottomRadius: The radius at the bottom
    ///   - topRadius: The radius at the top
    ///   - height: The height between the top and the bottom
    ///   - centerZ: If true, center the cylinder along the Z axis

    public init(bottomRadius: Double, topRadius: Double, height: Double, centerZ: Bool = false) {
        self.diameter = bottomRadius * 2
        self.topDiameter = topRadius * 2
        self.height = height
        self.centerZ = centerZ
    }

    public var invocation: Invocation {
        var params: [String: any SCADValue] = ["h": height]

        if centerZ {
            params["center"] = centerZ
        }

        if let topDiameter = topDiameter {
            params["d1"] = diameter
            params["d2"] = topDiameter
        } else {
            params["d"] = diameter
        }

        return .init(name: "cylinder", parameters: params)
    }

    public var boundary: Bounds {
        let bottomDiameter = diameter
        let topDiameter = self.topDiameter ?? diameter

        let bottom = Boundary2D.box([bottomDiameter, bottomDiameter]).asFlat3D()
        let top = Boundary2D.box([topDiameter, topDiameter]).asFlat3D(z: height)
        return .union([bottom, top])
    }
}
