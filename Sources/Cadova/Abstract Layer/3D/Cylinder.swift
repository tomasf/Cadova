import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the segmentation. See
/// ``Geometry/withSegmentation(minAngle:minSize:)`` and ``Geometry/withSegmentation(count:)``. For example, this code
/// creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .withSegmentation(count: 3)
/// ```

public struct Cylinder: Shape3D {
    public let height: Double
    public let bottomRadius: Double
    public let topRadius: Double

    public var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation
        let segmentCount = segmentation.segmentCount(circleRadius: max(bottomRadius, topRadius))

        if height < .ulpOfOne {
            Empty()

        } else if bottomRadius < .ulpOfOne {
            NodeBasedGeometry(.shape(.cylinder(
                bottomRadius: topRadius,
                topRadius: bottomRadius,
                height: height,
                segmentCount: segmentCount
            )))
            .flipped(along: .z)
            .translated(z: height)
        } else {
            NodeBasedGeometry(.shape(.cylinder(
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

public extension Cylinder {
    /// A circular representation of the top face of the cylinder.
    var top: Circle {
        Circle(radius: topRadius)
    }

    /// A circular representation of the bottom face of the cylinder.
    var bottom: Circle {
        Circle(radius: bottomRadius)
    }

    /// Returns the circular cross-section at a specific height `z` along the cylinder.
    ///
    /// - Parameter z: The height along the cylinder's axis, where 0 is the bottom and `height` is the top.
    /// - Returns: A `Circle` representing the cross-section at that height.
    func crossSection(at z: Double) -> Circle {
        Circle(radius: bottomRadius + (topRadius - bottomRadius) * z / height)
    }

    /// The slant height of the cylinder, which is the length of the side connecting the top and bottom edges.
    ///
    /// For a regular cylinder this is the same as `height`, but for a truncated cone it is the length
    /// of the diagonal between the top and bottom radii.
    var slantHeight: Double {
        (((topRadius - bottomRadius) * (topRadius - bottomRadius)) + height * height).squareRoot()
    }

    /// The lateral surface area, excluding the top and bottom faces.
    ///
    /// This is the curved surface area of the cylinder or cone.
    var lateralSurfaceArea: Double {
        (topRadius + bottomRadius) * .pi * slantHeight
    }

    /// The total surface area, including the top, bottom, and lateral surface.
    var surfaceArea: Double {
        lateralSurfaceArea + top.area + bottom.area
    }

    /// The volume of the solid, whether a full cylinder or truncated cone.
    var volume: Double {
        .pi / 3.0 * height * (bottomRadius * bottomRadius + bottomRadius * topRadius + topRadius * topRadius)
    }

    /// The angle between the side of the cylinder and its base.
    ///
    /// A value of 0 means the side is vertical (as in a regular cylinder).
    /// Positive angles indicate a flare outward (top radius > bottom radius),
    /// and negative angles indicate a taper inward (top radius < bottom radius).
    ///
    var sideAngle: Angle {
        atan((topRadius - bottomRadius) / height)
    }
}
