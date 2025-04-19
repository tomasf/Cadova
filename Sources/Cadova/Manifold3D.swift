import Manifold3D
import Foundation

extension Vector2D: Manifold3D.Vector2 {}
extension Vector3D: Manifold3D.Vector3 {}

extension AffineTransform2D: Manifold3D.Matrix2x3 {}
extension AffineTransform3D: Manifold3D.Matrix3x4 {}

extension Manifold3D.Vector2 {
    var vector2D: Vector2D { .init(x: x, y: y) }
}

extension Vector2D {
    public init(_ manifoldVector: any Vector2) {
        self.init(manifoldVector.x, manifoldVector.y)
    }
}

extension Manifold3D.Vector3 {
    var vector3D: Vector3D { .init(x: x, y: y, z: z) }
}

extension Vector3D {
    public init(_ manifoldVector: any Vector3) {
        self.init(manifoldVector.x, manifoldVector.y, manifoldVector.z)
    }
}

public protocol PrimitiveGeometry: Sendable {
    associatedtype D: Dimensionality
    associatedtype Vector
    associatedtype Matrix
    associatedtype Rotation

    static var empty: Self { get }
    init(composing: [Self])
    func decompose() -> [Self]

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

    func warp(_ function: @escaping (D.Vector) -> D.Vector) -> Self

    func applyingTransform(_ transform: AffineTransform3D) -> Self
}

extension CrossSection: PrimitiveGeometry {
    public typealias D = D2
    public typealias Matrix = any Matrix2x3
    public typealias Rotation = Double
    public typealias Vector = any Vector2

    public func applyingTransform(_ transform3D: AffineTransform3D) -> Self {
        transform(AffineTransform2D(transform3D))
    }

    public func warp(_ function: @escaping (D.Vector) -> D.Vector) -> Self {
        warp { v -> any Vector2 in function(.init(v)) }
    }
}

extension Manifold: PrimitiveGeometry {
    public typealias D = D3
    public typealias Vector = any Vector3
    public typealias Matrix = any Matrix3x4
    public typealias Rotation = any Vector3

    public func applyingTransform(_ transform3D: AffineTransform3D) -> Self {
        transform(transform3D)
    }

    public func warp(_ function: @escaping (D.Vector) -> D.Vector) -> Self {
        warp { v -> any Vector3 in function(.init(v)) }
    }
}

extension BoundingBox {
    init(_ p: (D.Primitive.Vector, D.Primitive.Vector)) {
        self.init(minimum: .init(p.0), maximum: .init(p.1))
    }

    var primitive: (D.Primitive.Vector, D.Primitive.Vector) {
        (minimum.primitive, maximum.primitive)
    }
}
