import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: Geometry3D {
    public let height: Double
    public let bottomDiameter: Double
    public let topDiameter: Double?

    public func evaluated(in environment: EnvironmentValues) -> Output3D {
        let topDiameter = self.topDiameter ?? bottomDiameter
        let segmentCount = environment.facets.facetCount(circleRadius: max(bottomDiameter, topDiameter) / 2)
        return .init(manifold: .cylinder(
            height: height,
            bottomRadius: bottomDiameter / 2,
            topRadius: topDiameter / 2,
            segmentCount: segmentCount
        ))
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
