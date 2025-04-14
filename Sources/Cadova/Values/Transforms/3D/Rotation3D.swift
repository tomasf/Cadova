import Foundation

// MARK: - Rotation3D

public struct Rotation3D: Sendable {
    // Internal quaternion components
    internal var qx: Double
    internal var qy: Double
    internal var qz: Double
    internal var qw: Double

    /// The identity rotation (no rotation).
    public static let none = Rotation3D(qx: 0, qy: 0, qz: 0, qw: 1)

    /// Creates a rotation from Euler angles in XYZ order.
    ///
    /// - Parameters:
    ///   - x: Rotation around the X axis.
    ///   - y: Rotation around the Y axis.
    ///   - z: Rotation around the Z axis.
    public init(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) {
        let cx = cos(0.5 * x), sx = sin(0.5 * x)
        let cy = cos(0.5 * y), sy = sin(0.5 * y)
        let cz = cos(0.5 * z), sz = sin(0.5 * z)

        self.qx = sx * cy * cz - cx * sy * sz
        self.qy = cx * sy * cz + sx * cy * sz
        self.qz = cx * cy * sz - sx * sy * cz
        self.qw = cx * cy * cz + sx * sy * sz
    }

    /// Creates a rotation from a rotation around a principal axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: The principal axis to rotate around.
    public init(angle: Angle, axis: Axis3D) {
        switch axis {
        case .x: self.init(x: angle)
        case .y: self.init(y: angle)
        case .z: self.init(z: angle)
        }
    }

    /// Creates a rotation from a rotation around an arbitrary axis.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation.
    ///   - axis: A unit direction vector representing the rotation axis.
    public init(angle: Angle, axis: Direction3D) {
        let half = 0.5 * angle.radians
        let s = sin(half)
        self.qx = axis.x * s
        self.qy = axis.y * s
        self.qz = axis.z * s
        self.qw = cos(half)
    }

    /// Creates a rotation from raw quaternion components.
    ///
    /// - Parameters:
    ///   - qx: The X component of the quaternion.
    ///   - qy: The Y component of the quaternion.
    ///   - qz: The Z component of the quaternion.
    ///   - qw: The scalar (real) component of the quaternion.
    public init(qx: Double, qy: Double, qz: Double, qw: Double) {
        self.qx = qx
        self.qy = qy
        self.qz = qz
        self.qw = qw
    }
}

extension Rotation3D: ExpressibleByArrayLiteral {
    public init(arrayLiteral angles: Angle...) {
        assert(angles.count == 3, "Rotation3D requires three angles")
        self.init(x: angles[0], y: angles[1], z: angles[2])
    }
}
