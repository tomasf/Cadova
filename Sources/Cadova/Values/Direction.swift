import Foundation

public struct Direction<D: Dimensionality>: Hashable, Sendable {
    public let unitVector: D.Vector

    public init(vector: D.Vector) {
        self.unitVector = vector.normalized
    }
}

public extension Direction <D3> {
    var x: Double { unitVector.x }
    var y: Double { unitVector.y }
    var z: Double { unitVector.z }

    init(x: Double = 0, y: Double = 0, z: Double = 0) {
        self.init(vector: .init(x, y, z))
    }

    init(from: D.Vector, to: D.Vector) {
        self.init(vector: to - from)
    }

    init(_ axis: D.Axis, _ direction: AxisDirection) {
        self.init(vector: .zero.with(axis, as: direction == .positive ? 1 : -1))
    }

    func rotated(angle: Angle, around other: Direction3D) -> Direction3D {
        .init(vector: AffineTransform3D.rotation(angle: angle, around: other).apply(to: unitVector))
    }
}

public typealias Direction3D = Direction<D3>

public extension Direction <D3> {
    static let positiveX = Direction(x: 1)
    static let negativeX = Direction(x: -1)
    static let positiveY = Direction(y: 1)
    static let negativeY = Direction(y: -1)
    static let positiveZ = Direction(z: 1)
    static let negativeZ = Direction(z: -1)

    static let up = positiveZ
    static let down = negativeZ
    static let forward = positiveY
    static let back = negativeY
    static let right = positiveX
    static let left = negativeX
}

public typealias Direction2D = Direction<D2>

public extension Direction <D2> {
    init(x: Double = 0, y: Double = 0) {
        self.init(vector: .init(x, y))
    }
}

public extension Direction <D2> {
    static let positiveX = Direction(x: 1)
    static let negativeX = Direction(x: -1)
    static let positiveY = Direction(y: 1)
    static let negativeY = Direction(y: -1)

    static let up = positiveY
    static let down = negativeY
    static let right = positiveX
    static let left = negativeX
}
