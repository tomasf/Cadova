import Foundation
import Testing
@testable import Cadova

struct MeshFaceTests {
    // The shoelace formula: positive for a polygon running counterclockwise.
    private func signedArea(_ polygon: [Vector2D]) -> Double {
        polygon.indices.reduce(0.0) { sum, index in
            let a = polygon[index], b = polygon[(index + 1) % polygon.count]
            return sum + a.x * b.y - a.y * b.x
        } / 2
    }

    @Test func `a face starting with collinear points keeps its shape when flattened`() {
        // A 10 × 10 square in a tilted plane, starting along a straight edge: its first three points don't describe
        // a plane, and taking the plane from them used to collapse the whole face onto a line.
        let tilt = Transform3D.rotation(x: 30°, y: -20°)
        let square: [Vector3D] = [[0, 0, 0], [5, 0, 0], [10, 0, 0], [10, 10, 0], [0, 10, 0]]
        #expect(signedArea(square.map { tilt.apply(to: $0) }.flattenCoplanar()) ≈ 100)
    }

    @Test func `a face whose first corner is concave keeps its direction when flattened`() {
        // An L shape, counterclockwise around +Z, starting at its inside corner, so its first three points turn
        // clockwise. Taking the plane from them used to mirror the whole face.
        let shape: [Vector3D] = [[10, 5, 2], [5, 5, 2], [5, 10, 2], [0, 10, 2], [0, 0, 2], [10, 0, 2]]
        #expect(signedArea(shape.flattenCoplanar()) ≈ 75)
    }
}
