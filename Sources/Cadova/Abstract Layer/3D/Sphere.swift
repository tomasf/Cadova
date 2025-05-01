import Foundation

/// A geometric representation of a sphere.
///
/// The sphere's smoothness and number of faces can be adjusted by configuring the segmentation through the ``Geometry/withSegmentation(minAngle:minSize:)`` and ``Geometry/withSegmentation(count:)`` methods, allowing for customized geometric precision and rendering quality.

public struct Sphere: CompositeGeometry {
    public typealias D = D3

    /// The diameter of the sphere.
    ///
    /// This property defines the overall size of the sphere from one side to the other through its center.
    var diameter: Double { radius * 2}

    /// The radius of the sphere.
    ///
    /// This property defines the overall size of the sphere from its center to its surface.
    let radius: Double

    /// Creates a sphere with the specified diameter.
    ///
    /// Use this initializer to create a sphere by directly specifying its diameter.
    /// - Parameter diameter: The diameter of the sphere.
    public init(diameter: Double) {
        self.init(radius: diameter / 2)
    }

    /// Creates a sphere with the specified radius.
    ///
    /// This initializer provides a convenient way to define a sphere's size through its radius, automatically calculating the appropriate diameter.
    /// - Parameter radius: The radius of the sphere. The diameter is calculated as twice the radius.
    public init(radius: Double) {
        self.radius = radius
    }

    @Environment(\.segmentation) private var segmentation

    public var body: D3.Geometry {
        NodeBasedGeometry(.shape(.sphere(
            radius: radius,
            segmentCount: segmentation.segmentCount(circleRadius: diameter / 2)
        )))
    }
}

public extension Sphere {
    static func ellipsoid(size: Vector3D) -> any Geometry3D {
        let diameter = max(size.x, size.y, size.z)
        return Sphere(diameter: diameter)
            .scaled(size / diameter)
    }

    static func ellipsoid(x: Double, y: Double, z: Double) -> any Geometry3D {
        ellipsoid(size: .init(x, y, z))
    }
}
