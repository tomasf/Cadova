import Foundation

public extension Vector3D {
    static func direction(_ axis: Axis3D, _ direction: AxisDirection) -> Vector3D {
        Vector3D.zero.with(axis, as: direction == .positive ? 1 : -1)
    }

    static let up: Vector3D = [0, 0, 1]
    static let down: Vector3D = [0, 0, -1]
    static let right: Vector3D = [1, 0, 0]
    static let left: Vector3D = [-1, 0, 0]
    static let forward: Vector3D = [0, 1, 0]
    static let backward: Vector3D = [0, -1, 0]
}
