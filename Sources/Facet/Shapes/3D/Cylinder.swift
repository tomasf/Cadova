import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: Geometry3D, LeafGeometry {
    public let height: Double
    public let bottomRadius: Double
    public let topRadius: Double

    public var topDiameter: Double { topRadius * 2 }
    public var bottomDiameter: Double { bottomRadius * 2 }

    @Environment(\.facets) private var facets

    var body: D3.Primitive {
        let segmentCount = facets.facetCount(circleRadius: max(bottomRadius, topRadius))

        if height < .ulpOfOne {
            return .empty

        } else if bottomRadius < .ulpOfOne {
            return .cylinder(
                height: height,
                bottomRadius: topRadius,
                topRadius: bottomRadius,
                segmentCount: segmentCount
            )
            .scale(Vector3D(1, 1, -1))
            .translate(Vector3D(0, 0, height))
        } else {
            return .cylinder(
                height: height,
                bottomRadius: bottomRadius,
                topRadius: topRadius,
                segmentCount: segmentCount
            )
        }
    }
}

public extension Cylinder {
    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder

    init(radius: Double, height: Double) {
        assert(radius > 0, "Cylinder radius must be positive")
        assert(height >= 0, "Cylinder height must not be negative")
        self.topRadius = radius
        self.bottomRadius = radius
        self.height = height
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom radii)
    /// - Parameters:
    ///   - bottomRadius: The radius at the bottom
    ///   - topRadius: The radius at the top
    ///   - height: The height between the top and the bottom

    init(bottomRadius: Double, topRadius: Double, height: Double) {
        assert(bottomRadius >= 0 && topRadius >= 0, "Cylinder radii must not be negative")
        assert(bottomRadius > 0 || topRadius > 0, "At least one of the radii must be positive")
        assert(height >= 0, "Cylinder height must not be negative")

        self.bottomRadius = bottomRadius
        self.topRadius = topRadius
        self.height = height
    }

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder

    init(diameter: Double, height: Double) {
        self.init(radius: diameter / 2, height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom

    init(bottomDiameter: Double, topDiameter: Double, height: Double) {
        self.init(bottomRadius: bottomDiameter / 2, topRadius: topDiameter / 2, height: height)
    }
}
