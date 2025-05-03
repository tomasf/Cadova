/// A unit-length direction vector in a given dimensionality.
///
/// `Direction` represents only the orientation of a vector, not its magnitude.
/// All directions are normalized upon creation.
public struct Direction<D: Dimensionality>: Hashable, Sendable, Codable {
    /// The normalized vector representing the direction.
    public let unitVector: D.Vector

    /// Creates a new direction by normalizing the provided vector.
    /// - Parameter vector: The vector whose direction is used.
    public init(_ vector: D.Vector) {
        self.unitVector = vector.normalized
    }
}

/// A direction in three-dimensional space.
public typealias Direction3D = Direction<D3>

/// A direction in two-dimensional space.
public typealias Direction2D = Direction<D2>

public extension Direction {
    /// Creates a direction pointing from one vector to another.
    /// - Parameters:
    ///   - from: The starting vector.
    ///   - to: The ending vector.
    init(from: D.Vector, to: D.Vector) {
        self.init(to - from)
    }

    /// Creates a direction aligned to a cartesian axis.
    /// - Parameters:
    ///   - axis: The axis to align to.
    ///   - direction: The direction along the axis (positive or negative).
    init(_ axis: D.Axis, _ direction: LinearDirection) {
        self.init(.zero.with(axis, as: direction == .positive ? 1 : -1))
    }

    /// Rotates the direction by an arbitrary rotation.
    /// - Parameter rotation: The rotation to apply.
    func rotated(_ rotation: D.Transform.Rotation) -> Self {
        .init(D.Transform.rotation(rotation).apply(to: unitVector))
    }
}

public extension Direction <D3> {
    /// The X component of the direction.
    var x: Double { unitVector.x }
    /// The Y component of the direction.
    var y: Double { unitVector.y }
    /// The Z component of the direction.
    var z: Double { unitVector.z }

    /// Creates a direction from x, y, z components.
    /// - Parameters:
    ///   - x: The x component of the direction.
    ///   - y: The y component of the direction.
    ///   - z: The z component of the direction.
    init(x: Double = 0, y: Double = 0, z: Double = 0) {
        self.init(D.Vector(x, y, z))
    }

    /// Rotates the direction by a given angle around another axis.
    /// - Parameters:
    ///   - angle: The angle to rotate.
    ///   - other: The direction around which to rotate.
    func rotated(angle: Angle, around other: Direction3D) -> Direction3D {
        .init(AffineTransform3D.rotation(angle: angle, around: other).apply(to: unitVector))
    }

    /// A direction pointing along the positive X axis.
    static let positiveX = Direction(x: 1)
    /// A direction pointing along the negative X axis.
    static let negativeX = Direction(x: -1)
    /// A direction pointing along the positive Y axis.
    static let positiveY = Direction(y: 1)
    /// A direction pointing along the negative Y axis.
    static let negativeY = Direction(y: -1)
    /// A direction pointing along the positive Z axis.
    static let positiveZ = Direction(z: 1)
    /// A direction pointing along the negative Z axis.
    static let negativeZ = Direction(z: -1)

    /// A direction pointing upward.
    static let up = positiveZ
    /// A direction pointing downward.
    static let down = negativeZ
    /// A direction pointing forward.
    static let forward = positiveY
    /// A direction pointing backward.
    static let back = negativeY
    /// A direction pointing to the right.
    static let right = positiveX
    /// A direction pointing to the left.
    static let left = negativeX
}

public extension Direction <D2> {
    /// The X component of the direction.
    var x: Double { unitVector.x }
    /// The Y component of the direction.
    var y: Double { unitVector.y }

    /// Creates a direction from X and Y components.
    /// - Parameters:
    ///   - x: The x component of the direction.
    ///   - y: The y component of the direction.
    init(x: Double = 0, y: Double = 0) {
        self.init(.init(x, y))
    }

    /// Returns the direction as an angle, measured counterclockwise from the positive X axis.
    var angle: Angle {
        atan2(y, x)
    }

    /// Creates a direction from an angle measured counterclockwise from the positive X axis.
    /// - Parameter angle: The angle representing the direction.
    init(angle: Angle) {
        self.init(x: cos(angle), y: sin(angle))
    }

    /// A direction pointing along the positive X axis.
    static let positiveX = Direction(x: 1)
    /// A direction pointing along the negative X axis.
    static let negativeX = Direction(x: -1)
    /// A direction pointing along the positive Y axis.
    static let positiveY = Direction(y: 1)
    /// A direction pointing along the negative Y axis.
    static let negativeY = Direction(y: -1)

    /// A direction pointing upward.
    static let up = positiveY
    /// A direction pointing downward.
    static let down = negativeY
    /// A direction pointing to the right.
    static let right = positiveX
    /// A direction pointing to the left.
    static let left = negativeX
}
