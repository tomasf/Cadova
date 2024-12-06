import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: LeafGeometry3D {
    public let height: Double
    public let bottomDiameter: Double
    public let topDiameter: Double?

    var moduleName: String { "cylinder" }
    var moduleParameters: CodeFragment.Parameters {
        if let topDiameter {
            ["d1": bottomDiameter, "d2": topDiameter, "h": height]
        } else {
            ["d": bottomDiameter, "h": height]
        }
    }

    public func boundary(in environment: EnvironmentValues) -> Bounds {
        let bottom = Boundary2D.circle(radius: bottomDiameter / 2, facets: environment.facets)
        let top = Boundary2D.circle(radius: (topDiameter ?? bottomDiameter) / 2, facets: environment.facets)
        return .union(
            bottom.as3D(),
            top.as3D(z: height)
        )
    }
}

public extension Cylinder {
    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder

    init(diameter: Double, height: Double) {
        assert(diameter >= 0, "Cylinder diameter must not be negative")
        assert(height >= 0, "Cylinder height must not be negative")
        self.bottomDiameter = diameter
        self.topDiameter = nil
        self.height = height
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom

    init(bottomDiameter: Double, topDiameter: Double, height: Double) {
        assert(bottomDiameter >= 0 && topDiameter >= 0, "Cylinder diameters must not be negative")
        assert(height >= 0, "Cylinder height must not be negative")
        self.bottomDiameter = bottomDiameter
        self.topDiameter = topDiameter
        self.height = height
    }

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder

    init(radius: Double, height: Double) {
        self.init(diameter: radius * 2, height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom radii)
    /// - Parameters:
    ///   - bottomRadius: The radius at the bottom
    ///   - topRadius: The radius at the top
    ///   - height: The height between the top and the bottom

    init(bottomRadius: Double, topRadius: Double, height: Double) {
        self.init(bottomDiameter: bottomRadius * 2, topDiameter: topRadius * 2, height: height)
    }
}
