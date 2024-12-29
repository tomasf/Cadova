import Foundation
import Manifold

internal extension Polyhedron {
    func triangulated() -> Polyhedron {
        let newFaces = faces.flatMap { face in
            guard face.count > 3 else { return [face] }
            let flat = Manifold.Polygon(vertices: face.map { vertices[$0] }.flattenCoplanar())
            return triangulate(polygons: [flat], epsilon: 1e-6).map {
                [face[$0.a], face[$0.b], face[$0.c]]
            }
        }

        return Polyhedron(vertices: vertices, faces: newFaces)
    }
}

internal extension [Vector3D] {
    /// Flattens an array of coplanar 3D points into 2D.
    /// The output has the same ordering as the input.
    func flattenCoplanar() -> [Vector2D] {
        assert(count >= 3)

        let firstToSecond = self[1] - self[0]
        let firstToThird = self[2] - self[0]
        let planeNormal = (firstToSecond × firstToThird).normalized
        let v1 = firstToSecond.normalized
        let v2 = planeNormal × v1

        return map { point in
            let relative = point - self[0]
            return Vector2D(relative ⋅ v1, relative ⋅ v2)
        }
    }
}
