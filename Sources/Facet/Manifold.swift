import Manifold
import Foundation

extension Vector2D: Manifold.Vector2 {}
extension Vector3D: Manifold.Vector3 {}

extension AffineTransform2D: Manifold.Matrix2x3 {}
extension AffineTransform3D: Manifold.Matrix3x4 {}

extension Manifold.Vector2 {
    var vector2D: Vector2D { .init(x: x, y: y) }
}

public extension Vector2D {
    init(_ manifoldVector: any Vector2) {
        self.init(manifoldVector.x, manifoldVector.y)
    }
}

extension Manifold.Vector3 {
    var vector3D: Vector3D { .init(x: x, y: y, z: z) }
}

public extension Vector3D {
    init(_ manifoldVector: any Vector3) {
        self.init(manifoldVector.x, manifoldVector.y, manifoldVector.z)
    }
}

public protocol PrimitiveGeometry {
    associatedtype Vector
    associatedtype Matrix
    associatedtype Rotation

    static var empty: Self { get }

    var isEmpty: Bool { get }
    var bounds: (min: Vector, max: Vector) { get }
    var vertexCount: Int { get }

    func transform(_ transform: Matrix) -> Self
    func translate(_ translation: Vector) -> Self
    func scale(_ scale: Vector) -> Self
    func rotate(_ rotation: Rotation) -> Self

    func boolean(_ op: BooleanOperation, with other: Self) -> Self
    static func boolean(_ op: BooleanOperation, with children: [Self]) -> Self

    func hull() -> Self
    static func hull(_ children: [Self]) -> Self
    static func hull(_ points: [Vector]) -> Self

    func warp(_ function: @escaping (Vector) -> Vector) -> Self
}

extension CrossSection: PrimitiveGeometry {
    public typealias Vector = any Vector2
    public typealias Matrix = any Matrix2x3
    public typealias Rotation = Double
}

extension Mesh: PrimitiveGeometry {
    public typealias Vector = any Vector3
    public typealias Matrix = any Matrix3x4
    public typealias Rotation = any Vector3
}

extension BoundingBox {
    init(_ p: (D.Primitive.Vector, D.Primitive.Vector)) {
        self.init(minimum: .init(p.0), maximum: .init(p.1))
    }
}
