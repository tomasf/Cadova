import Foundation

/// A geometric representation of a sphere.
///
/// The sphere's smoothness and number of faces can be adjusted by configuring the segmentation through the ``Geometry/withSegmentation(minAngle:minSize:)`` and ``Geometry/withSegmentation(count:)`` methods, allowing for customized geometric precision and rendering quality.

public struct Sphere: Hashable, Sendable, Codable {
    /// The radius of the sphere.
    ///
    /// This property defines the overall size of the sphere from its center to its surface.
    public let radius: Double

    /// Creates a sphere with the specified diameter.
    ///
    /// Use this initializer to create a sphere by directly specifying its diameter.
    /// - Parameter diameter: The diameter of the sphere. A value of zero or less results in empty geometry.
    public init(diameter: Double) {
        precondition(diameter.isFinite, "Sphere diameter must be finite")
        self.init(radius: diameter / 2)
    }

    /// Creates a sphere with the specified radius.
    ///
    /// This initializer provides a convenient way to define a sphere's size through its radius, automatically calculating the appropriate diameter.
    /// - Parameter radius: The radius of the sphere. The diameter is calculated as twice the radius. A value of zero or less results in empty geometry.
    public init(radius: Double) {
        precondition(radius.isFinite, "Sphere radius must be finite")
        self.radius = radius
    }
}

extension Sphere: Geometry3D {
    public var body: any Geometry3D {
        @Environment(\.scaledSegmentation) var segmentation
        StaticNodeGeometry(.sphere(
            radius: radius,
            segmentCount: segmentation.segmentCount(circleRadius: diameter / 2)
        ))
    }
}

public extension Sphere {
    /// Creates an ellipsoid filling the given size.
    ///
    /// - Parameter size: The extent of the ellipsoid along each axis. A size with any dimension of zero
    ///   or less results in empty geometry.
    @GeometryBuilder3D
    static func ellipsoid(size: Vector3D) -> any Geometry3D {
        // The sphere this is scaled from has the largest dimension as its diameter, so that dimension is
        // what there is to scale. Every dimension has to be positive, though: a negative one survives the
        // scale as a mirror, turning the ellipsoid inside out where the caller asked for nothing.
        let diameter = max(size.x, size.y, size.z)
        if min(size.x, size.y, size.z) > 0 {
            Sphere(diameter: diameter)
                .scaled(size / diameter)
        }
    }

    /// Creates an ellipsoid filling the given extents.
    ///
    /// - Parameters:
    ///   - x: The extent of the ellipsoid along the X axis.
    ///   - y: The extent of the ellipsoid along the Y axis.
    ///   - z: The extent of the ellipsoid along the Z axis.
    ///
    /// A size with any dimension of zero or less results in empty geometry.
    static func ellipsoid(x: Double, y: Double, z: Double) -> any Geometry3D {
        ellipsoid(size: .init(x, y, z))
    }
}

public extension Sphere {
    /// The diameter of the sphere.
    ///
    /// This property defines the overall size of the sphere from one side to the other through its center.
    var diameter: Double { radius * 2}

    /// The surface area of the sphere.
    var surfaceArea: Double {
        4 * .pi * radius * radius
    }

    /// The volume of the sphere.
    var volume: Double {
        (4.0 / 3.0) * .pi * radius * radius * radius
    }
}
