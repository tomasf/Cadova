import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the segmentation. See ``Geometry/withSegmentation(minAngle:minSize:)`` and ``Geometry/withSegmentation(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .withSegmentation(count: 3)
/// ```

public struct Cylinder: Shape3D {
    public let height: Double
    public let bottomRadius: Double
    public let topRadius: Double

    public var topDiameter: Double { topRadius * 2 }
    public var bottomDiameter: Double { bottomRadius * 2 }

    @Environment(\.segmentation) private var segmentation

    public var body: any Geometry3D {
        let segmentCount = segmentation.segmentCount(circleRadius: max(bottomRadius, topRadius))

        if height < .ulpOfOne {
            return Empty()

        } else if bottomRadius < .ulpOfOne {
            return NodeBasedGeometry(.shape(.cylinder(
                bottomRadius: topRadius,
                topRadius: bottomRadius,
                height: height,
                segmentCount: segmentCount
            )))
            .scaled(z: -1)
            .translated(z: height)
        } else {
            return NodeBasedGeometry(.shape(.cylinder(
                bottomRadius: bottomRadius,
                topRadius: topRadius,
                height: height,
                segmentCount: segmentCount
            )))
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
