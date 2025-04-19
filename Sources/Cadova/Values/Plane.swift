import Foundation

/// A geometric plane in 3D space, defined by an offset point and a normal vector.
///
/// The plane is represented in the form: `ax + by + cz + d = 0`, where `(a, b, c)` is the normal vector and `d` is derived from the offset point.
///
/// You can initialize a `Plane` in several ways:
/// - Using a point and a normal vector.
/// - Using three points (non-collinear) lying on the plane.
/// - Using a plane perpendicular to a specific Cartesian axis at a specified offset.
public struct Plane: Hashable, Sendable, Codable {
    /// A point lying on the plane.
    public let offset: Vector3D

    /// The unit normal vector of the plane.
    public let normal: Direction3D

    /// Creates a plane from an offset point and a normal vector.
    /// - Parameters:
    ///   - offset: A point lying on the plane.
    ///   - normal: The plane's normal direction.
    public init(offset: Vector3D, normal: D3.Direction) {
        self.offset = offset
        self.normal = normal
    }
}

internal extension Plane {
    private var equation: (a: Double, b: Double, c: Double, d: Double) {
        let d = -(normal.x * offset.x + normal.y * offset.y + normal.z * offset.z)
        return (normal.x, normal.y, normal.z, d)
    }
}

public extension Plane {
    /// Initializes a plane using three non-collinear points.
    ///
    /// The normal vector is computed using the cross product of vectors defined by the three points.
    /// - Parameters:
    ///   - point1: First point on the plane.
    ///   - point2: Second point on the plane.
    ///   - point3: Third point on the plane. Must not be collinear with the other two.
    init(point1: Vector3D, point2: Vector3D, point3: Vector3D) {
        let vector1 = point2 - point1
        let vector2 = point3 - point1
        let normalVector = (vector1 × vector2).normalized
        precondition(normalVector.magnitude > 0, "The points must not be collinear.")
        self.offset = point1
        self.normal = .init(vector: normalVector)
    }

    /// Initializes a plane perpendicular to the specified Cartesian axis at the given offset.
    /// - Parameters:
    ///   - axis: The axis perpendicular to the plane.
    ///   - offset: The plane's offset along the axis.
    init(perpendicularTo axis: Axis3D, at offset: Double = 0) {
        let direction = Direction(axis, .positive)
        self.init(offset: direction.unitVector * offset, normal: direction)
    }

    /// Creates a plane perpendicular to the X-axis.
    init(x offset: Double) {
        self.init(perpendicularTo: .x, at: offset)
    }

    /// Creates a plane perpendicular to the Y-axis.
    init(y offset: Double) {
        self.init(perpendicularTo: .y, at: offset)
    }

    /// Creates a plane perpendicular to the Z-axis.
    init(z offset: Double) {
        self.init(perpendicularTo: .z, at: offset)
    }
}

public extension Plane {
    /// Computes the signed distance from a point to the plane.
    ///
    /// Positive values indicate the point lies in the direction of the normal vector.
    /// - Parameter point: The point whose distance to the plane is measured.
    /// - Returns: The signed distance.
    func distance(to point: Vector3D) -> Double {
        let (a, b, c, d) = equation
        return (a * point.x + b * point.y + c * point.z + d)
    }

    /// Projects a 3D point orthogonally onto the plane.
    ///
    /// This method computes the closest point on the plane to the input point by dropping a perpendicular line from the point to the plane.
    ///
    /// The projection is calculated by determining the signed distance from the point to the plane and moving the point along the plane's normal vector by that distance.
    ///
    /// - Parameter point: The point to be projected onto the plane.
    /// - Returns: The closest point on the plane.
    func project(point: Vector3D) -> Vector3D {
        let distanceToPlane = distance(to: point)
        return point - normal.unitVector * distanceToPlane
    }

    /// Returns a transformation that aligns the plane with the XY plane.
    var transform: AffineTransform3D {
        .rotation(from: .positiveZ, to: normal).translated(offset)
    }
}

public extension Plane {
    /// Visualizes the plane as a thin, large cylinder, useful for debugging or presentation.
    /// - Parameters:
    ///   - radius: Radius of the cylinder used to represent the plane.
    ///   - thickness: Thickness of the cylinder.
    /// - Returns: A geometry object representing the plane.
    func visualized(radius: Double = 100, thickness: Double = 0.05) -> any Geometry3D {
        Cylinder(radius: radius, height: thickness)
            .rotated(from: .up, to: normal)
            .translated(offset)
            .withMaterial(.visualizedPlane)
            .inPart(named: "Visualized Plane", type: .visual)
    }
}
