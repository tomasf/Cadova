import Foundation

public struct Plane {
    public let offset: Vector3D
    public let normal: D3.Direction

    public init(offset: Vector3D, normal: D3.Direction) {
        self.offset = offset
        self.normal = normal
    }
}

public extension Plane {
    /// Initialize a plane using three points.
    init(point1: Vector3D, point2: Vector3D, point3: Vector3D) {
        let vector1 = point2 - point1
        let vector2 = point3 - point1
        let normalVector = (vector1 × vector2).normalized
        precondition(normalVector.magnitude > 0, "The points must not be collinear.")
        self.offset = point1
        self.normal = .init(vector: normalVector)
    }

    init(perpendicularTo axis: Axis3D, at offset: Double = 0) {
        let direction = Direction(axis, .positive)
        self.init(offset: direction.unitVector * offset, normal: direction)
    }
}

public extension Plane {
    private var equation: (a: Double, b: Double, c: Double, d: Double) {
        let d = -(normal.x * offset.x + normal.y * offset.y + normal.z * offset.z)
        return (normal.x, normal.y, normal.z, d)
    }

    func distance(to point: Vector3D) -> Double {
        let (a, b, c, d) = equation
        return (a * point.x + b * point.y + c * point.z + d)
    }

    func project(point: Vector3D) -> Vector3D {
        let distanceToPlane = distance(to: point)
        return point - normal.unitVector * distanceToPlane
    }
}

public extension Plane {
    func visualized(radius: Double = 100, thickness: Double = 0.05) -> any Geometry3D {
        Cylinder(radius: radius, height: thickness)
            .rotated(from: .up, to: normal)
            .translated(offset)
            .withMaterial(.visualizedPlane)
            .background()
    }
}
