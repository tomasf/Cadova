import Foundation
import Manifold3D

public extension Geometry3D {
    /// Offsets the geometry's surface by a distance.
    ///
    /// Every point of the result's surface lies at `amount` from the original surface. A positive amount grows the
    /// geometry outward: flat faces move out in parallel, and convex edges and corners become rounded with the
    /// amount as radius. A negative amount shrinks it inward: concave edges and corners become rounded instead, and
    /// parts thinner than twice the amount disappear.
    ///
    /// The result is computed from the exact distance to the surface, so flat faces and sharp creases stay exact.
    /// Rounded parts follow the environment's segmentation, like circles do.
    ///
    /// - Parameter amount: The distance to offset by. Positive values grow the geometry, negative values shrink it.
    /// - Returns: The offset geometry.
    ///
    func offset(amount: Double) -> any Geometry3D {
        Offset3D(source: self, amount: amount)
    }

    /// Offsets the geometry's surface by a distance, providing both the original and offset geometries to a builder
    /// closure.
    ///
    /// This enables further composition, such as combining the two or constructing additional geometry based on
    /// their relationship.
    ///
    /// - Parameters:
    ///   - amount: The distance to offset by. Positive values grow the geometry, negative values shrink it.
    ///   - reader: A closure that receives both the original geometry and the offset geometry, and returns a new
    ///     composed geometry.
    /// - Returns: The result of the builder closure.
    ///
    /// - SeeAlso: ``offset(amount:)``
    ///
    func offset<Output: Dimensionality>(
        amount: Double,
        @GeometryBuilder<Output> reader: @escaping @Sendable (_ original: any Geometry3D, _ offset: any Geometry3D) -> Output.Geometry
    ) -> Output.Geometry {
        reader(self, offset(amount: amount))
    }
}

private struct Offset3D: Geometry3D {
    let source: any Geometry3D
    let amount: Double

    var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation
        if amount == 0 {
            source
        } else {
            let cellSize = segmentation.offsetCellSize(radius: abs(amount))
            CachedConcreteTransformer(body: source, name: "Cadova.Offset3D", parameters: amount, cellSize) { manifold in
                let mesh = manifold.meshGL()
                let faces = mesh.triangles.map { ($0.a, $0.b, $0.c) }
                guard !faces.isEmpty else { return manifold }
                let field = MeshDistanceField(vertices: mesh.vertices, faces: faces)
                let result = MeshOffset(field: field, amount: amount, cellSize: cellSize, tolerance: cellSize / 10).run()
                guard !result.faces.isEmpty else { return .empty }
                let triangles = result.faces.map { Manifold3D.Triangle($0.0, $0.1, $0.2) }
                return try Manifold(MeshGL(vertices: result.vertices, triangles: triangles))
            }
        }
    }
}

internal extension Segmentation {
    /// The cell size for offsetting a surface, whose rounded parts have the given radius: adaptive segmentation's
    /// shortest segment, or for a fixed count, the segment length of a circle of that radius
    func offsetCellSize(radius: Double) -> Double {
        switch self {
        case .fixed(let count):
            return 2 * .pi * radius / Double(max(count, 3))
        case .adaptive(_, let minSize):
            return minSize
        }
    }
}
