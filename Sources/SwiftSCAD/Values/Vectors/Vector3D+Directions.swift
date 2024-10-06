import Foundation

public extension Vector3D {
    static func direction(_ axis: Axis3D, _ direction: AxisDirection) -> Vector3D {
        Vector3D.zero.with(axis, as: direction == .positive ? 1 : -1)
    }

    static let positiveX: Vector3D = [1, 0, 0]
    static let negativeX: Vector3D = [-1, 0, 0]
    static let positiveY: Vector3D = [0, 1, 0]
    static let negativeY: Vector3D = [0, -1, 0]
    static let positiveZ: Vector3D = [0, 0, 1]
    static let negativeZ: Vector3D = [0, 0, -1]

    static let up: Vector3D = positiveZ
    static let down: Vector3D = negativeZ
    static let right: Vector3D = positiveX
    static let left: Vector3D = negativeX
    static let forward: Vector3D = positiveY
    static let backward: Vector3D = negativeY
}
