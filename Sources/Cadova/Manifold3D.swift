import Manifold3D
import Foundation

public typealias Manifold = Manifold3D.Manifold<Vector3D>
public typealias CrossSection = Manifold3D.CrossSection<Vector2D>
public typealias ManifoldPolygon = Manifold3D.Polygon<Vector2D>
public typealias MeshGL = Manifold3D.MeshGL<Vector3D>

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

public protocol PrimitiveGeometry<V>: Sendable {
    associatedtype V: Vector
    associatedtype D: Dimensionality where D.Vector == V
    associatedtype Rotation

    static var empty: Self { get }
    init(composing: [Self])
    func decompose() -> [Self]

    var isEmpty: Bool { get }
    var bounds: (min: V, max: V) { get }
    var vertexCount: Int { get }

    func transform(_ transform: D.Transform) -> Self
    func translate(_ translation: V) -> Self
    func scale(_ scale: V) -> Self
    func rotate(_ rotation: Rotation) -> Self

    func boolean(_ op: BooleanOperation, with other: Self) -> Self
    static func boolean(_ op: BooleanOperation, with children: [Self]) -> Self

    func hull() -> Self
    static func hull(_ children: [Self]) -> Self
    static func hull(_ points: [V]) -> Self

    func warp(_ function: @escaping (V) -> V) -> Self
    func simplify(epsilon: Double) -> Self

    func allVertices() -> [V]
}

extension CrossSection: PrimitiveGeometry {
    public typealias D = D2
    public typealias Rotation = Double

    public func allVertices() -> [V] {
        polygons().flatMap(\.vertices)
    }
}

extension Manifold: PrimitiveGeometry {
    public typealias D = D3
    public typealias Rotation = Vector3D

    public func allVertices() -> [V] {
        meshGL().vertices
    }
}
