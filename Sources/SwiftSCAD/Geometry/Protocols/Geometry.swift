import Foundation

/// Two-dimensional geometry
public protocol Geometry2D {
    typealias Output = GeometryOutput<Vector2D>
    typealias Bounds = Boundary<Vector2D>

    func output(in environment: Environment) -> Output
}

/// Three-dimensional geometry
public protocol Geometry3D {
    typealias Output = GeometryOutput<Vector3D>
    typealias Bounds = Boundary<Vector3D>

    func output(in environment: Environment) -> Output
}
