import Foundation

internal protocol AttractionTarget<D>: Sendable, Hashable, Codable {
    associatedtype D: Dimensionality
    func pullTarget(for point: D.Vector) -> D.Vector
}

extension Vector2D: AttractionTarget {
    func pullTarget(for point: Vector2D) -> Vector2D { self }
}

extension Vector3D: AttractionTarget {
    func pullTarget(for point: Vector3D) -> Vector3D { self }
}

extension Line: AttractionTarget {
    func pullTarget(for point: D.Vector) -> D.Vector {
        self.closestPoint(to: point)
    }
}

extension Plane: AttractionTarget {
    typealias D = D3

    func pullTarget(for point: Vector3D) -> Vector3D {
        project(point: point)
    }
}
