import Foundation

/// Any geometry, 2D or 3D
public protocol Geometry {
    associatedtype V: Vector
    typealias Output = GeometryOutput<V>
    typealias Bounds = Boundary<V>

    func output(in environment: Environment) -> Output
}

/// Two-dimensional geometry
public protocol Geometry2D: Geometry where V == Vector2D {}


/// Three-dimensional geometry
public protocol Geometry3D: Geometry where V == Vector3D {}
