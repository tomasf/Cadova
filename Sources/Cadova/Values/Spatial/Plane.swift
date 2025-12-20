import Foundation
#if canImport(simd)
import simd
#endif

/// A geometric plane in 3D space, defined by a point on the plane and a unit normal.
///
/// The implicit form is `ax + by + cz + d = 0`, where `(a, b, c)` is the unit normal and `d` is derived from the offset point.
///
/// ### Construction
/// You can create a `Plane` by:
/// - Providing a point (`offset`) and a normal (`normal`).
/// - Providing three non‑collinear points.
/// - Choosing a Cartesian axis the plane is perpendicular to, at a given offset.
public struct Plane: Hashable, Sendable, Codable {
    /// A point lying on the plane (not necessarily the closest to the origin).
    public let offset: Vector3D

    /// The plane's outward unit normal.
    public let normal: Direction3D

    /// Creates a plane from a point and a unit normal.
    /// - Parameters:
    ///   - offset: Any point on the plane.
    ///   - normal: The plane's unit normal (direction is preserved as given).
    public init(offset: Vector3D, normal: Direction3D) {
        self.offset = offset
        self.normal = normal
    }
}

extension Plane: CustomStringConvertible {
    public var description: String {
        String(format: "Plane(offset: [%g, %g, %g], normal: [%g, %g, %g])", offset.x, offset.y, offset.z, normal.x, normal.y, normal.z)
    }
}

internal extension Plane {
    private var equation: (a: Double, b: Double, c: Double, d: Double) {
        let d = -(normal.x * offset.x + normal.y * offset.y + normal.z * offset.z)
        return (normal.x, normal.y, normal.z, d)
    }
}

public extension Plane {
    /// Creates a plane through three non‑collinear points.
    ///
    /// The normal is computed as `(point2 - point1) × (point3 - point1)` and normalized.
    /// - Parameters:
    ///   - point1: First point on the plane.
    ///   - point2: Second point on the plane.
    ///   - point3: Third point (must not be collinear with the first two).
    init(point1: Vector3D, point2: Vector3D, point3: Vector3D) {
        let normalVector = ((point2 - point1) × (point3 - point1)).normalized
        precondition(normalVector.magnitude > 0, "The points must not be collinear.")
        self.offset = point1
        self.normal = .init(normalVector)
    }

    /// Creates a plane perpendicular to a Cartesian axis at a given offset.
    /// - Parameters:
    ///   - axis: The axis the plane is perpendicular to.
    ///   - offset: Distance along `axis` from the origin to the plane.
    init(perpendicularTo axis: Axis3D, at offset: Double = 0) {
        let direction = Direction<D3>(axis, .positive)
        self.init(offset: direction.unitVector * offset, normal: direction)
    }

    /// Creates a plane coincident with a face of a bounding box, optionally offset outward.
    ///
    /// The plane is perpendicular to `side.axis` and passes through the corresponding box face, shifted
    /// by `offset` in the direction of `side`.
    /// - Parameters:
    ///   - side: The directional axis (axis + direction) the plane is perpendicular to.
    ///   - box: The reference bounding box.
    ///   - offset: Additional distance from the box face along `side` (default: `0`).
    init(side: DirectionalAxis<D3>, on box: BoundingBox3D, offset: Double = 0) {
        self.init(
            offset: .init(side.axis, value: box[side.axis, side.axisDirection] + offset * side.axisDirection.factor),
            normal: side.direction
        )
    }

    /// Creates a vertical plane from a 2D line lying in the XY plane.
    ///
    /// The plane passes through `line.point` (lifted to `Z = 0`) and has a normal equal to the line’s
    /// clockwise 2D normal embedded in 3D. Its intersection with the XY plane is exactly the given line.
    ///
    /// - Parameter line: The 2D line to lift into 3D as a plane.
    ///
    init(line: Line<D2>) {
        self.init(
            offset: Vector3D(line.point),
            normal: Direction3D(Vector3D(line.direction.clockwiseNormal.unitVector))
        )
    }

    /// Plane perpendicular to +X at `x = offset`.
    static func x(_ offset: Double) -> Self {
        .init(perpendicularTo: .x, at: offset)
    }

    /// Plane perpendicular to +Y at `y = offset`.
    static func y(_ offset: Double) -> Self {
        .init(perpendicularTo: .y, at: offset)
    }

    /// Plane perpendicular to +Z at `z = offset`.
    static func z(_ offset: Double) -> Self {
        .init(perpendicularTo: .z, at: offset)
    }

    /// Canonical coordinate planes through the origin.
    static let xy = Plane(perpendicularTo: .z, at: 0)
    static let xz = Plane(perpendicularTo: .y, at: 0)
    static let yz = Plane(perpendicularTo: .x, at: 0)

    /// Returns the same plane with its normal reversed.
    var flipped: Self {
        Self(offset: offset, normal: normal.opposite)
    }

    /// Returns a parallel plane shifted by `amount` along this plane’s normal.
    ///
    /// Positive values move in the direction of `normal`; negative values move opposite.
    /// - Parameter amount: Signed distance along the normal.
    func offset(_ amount: Double) -> Self {
        Self(offset: offset + normal.unitVector * amount, normal: normal)
    }
}

public extension Plane {
    /// Signed distance from a point to the plane (positive in the direction of the normal).
    /// - Parameter point: The point whose distance to the plane is measured.
    /// - Returns: The signed distance.
    func distance(to point: Vector3D) -> Double {
        let (a, b, c, d) = equation
        return (a * point.x + b * point.y + c * point.z + d)
    }

    /// Orthogonally projects a 3D point onto the plane (closest point).
    /// - Parameter point: The point to be projected onto the plane.
    /// - Returns: The closest point on the plane.
    func project(point: Vector3D) -> Vector3D {
        let distanceToPlane = distance(to: point)
        return point - normal.unitVector * distanceToPlane
    }

    /// A transform that places XY‑plane geometry onto this plane.
    ///
    /// Applying this transform to geometry rotates it so +Z aligns with `normal`
    /// and then translates it to `offset`.
    var transform: Transform3D {
        .rotation(from: .positiveZ, to: normal).translated(offset)
    }

    /// Intersects the plane with a 3D line.
    ///
    /// - Parameter line: The line to test.
    /// - Returns: The intersection point, or `nil` if the line is parallel to the plane.
    func intersection(with line: Line<D3>) -> Vector3D? {
        let lineDir = line.direction.unitVector
        let denom = lineDir ⋅ normal.unitVector

        // If denom is close to zero, the line is parallel to the plane
        guard abs(denom) > 1e-8 else {
            return nil
        }

        let diff = offset - line.point
        let t = (diff ⋅ normal.unitVector) / denom
        return line.point + lineDir * t
    }

    /// Intersects this plane with another plane.
    ///
    /// - Parameter other: The second plane.
    /// - Returns: The intersection line, or `nil` if the planes are parallel or coincident.
    func intersection(with other: Plane) -> Line<D3>? {
        let n1 = self.normal.unitVector
        let n2 = other.normal.unitVector

        let direction = n1 × n2
        if direction.magnitude < 1e-8 {
            return nil
        }

        let (a1, b1, c1, d1) = self.equation
        let (a2, b2, c2, d2) = other.equation

        let matrix = Matrix3x3(rows: [
            [a1, b1, c1],
            [a2, b2, c2],
            [direction.x, direction.y, direction.z]
        ])

        let column = Matrix3x3.Column(-d1, -d2, 0)
        let point: Matrix3x3.Row = matrix.inverse * column
        return Line(point: .init(point[0], point[1], point[2]), direction: Direction3D(direction))
    }
}
