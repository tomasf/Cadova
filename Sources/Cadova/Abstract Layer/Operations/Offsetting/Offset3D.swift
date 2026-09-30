import Foundation
import Manifold3D

public extension Geometry3D {
    /// Offsets the geometry's surface by a distance.
    ///
    /// A positive amount grows the geometry outward, and a negative amount shrinks it inward. Flat faces move in
    /// parallel by the amount, and parts thinner than twice an inward amount disappear. The style decides what
    /// happens where faces move apart, at convex edges and corners when growing and at concave ones when shrinking:
    ///
    /// - `.round` rounds them with the amount as radius. Every point of the surface then lies exactly at the amount
    ///   from the original surface, which is what uniform walls need.
    /// - `.miter` extends the faces until they meet, keeping edges and corners sharp. Where that would reach farther
    ///   than the environment's miter limit times the amount, it squares off instead.
    /// - `.square` cuts them flat at the amount from the original edge or corner.
    /// - `.bevel` cuts them flat between the moved faces.
    ///
    /// Only edges and corners sharp enough for the style to make a visible difference are treated this way; curved
    /// surfaces, made of many nearly flat faces, stay smooth. The result is computed from the exact distance to the
    /// surface, so flat faces and sharp creases stay exact. Rounded parts follow the environment's segmentation, like
    /// circles do.
    ///
    /// - Parameters:
    ///   - amount: The distance to offset by. Positive values grow the geometry, negative values shrink it.
    ///   - style: How edges and corners are joined where faces move apart. Defaults to `.round`.
    /// - Returns: The offset geometry.
    ///
    func offset(amount: Double, style: LineJoinStyle = .round) -> any Geometry3D {
        Offset3D(source: self, amount: amount, style: style)
    }

    /// Offsets the geometry's surface by a distance, providing both the original and offset geometries to a builder
    /// closure.
    ///
    /// This enables further composition, such as combining the two or constructing additional geometry based on
    /// their relationship.
    ///
    /// - Parameters:
    ///   - amount: The distance to offset by. Positive values grow the geometry, negative values shrink it.
    ///   - style: How edges and corners are joined where faces move apart. Defaults to `.round`.
    ///   - reader: A closure that receives both the original geometry and the offset geometry, and returns a new
    ///     composed geometry.
    /// - Returns: The result of the builder closure.
    ///
    /// - SeeAlso: ``offset(amount:style:)``
    ///
    func offset<Output: Dimensionality>(
        amount: Double,
        style: LineJoinStyle = .round,
        @GeometryBuilder<Output> reader: @escaping @Sendable (_ original: any Geometry3D, _ offset: any Geometry3D) -> Output.Geometry
    ) -> Output.Geometry {
        reader(self, offset(amount: amount, style: style))
    }
}

private struct Offset3D: Geometry3D {
    let source: any Geometry3D
    let amount: Double
    let style: LineJoinStyle

    var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation
        @Environment(\.miterLimit) var miterLimit
        if amount == 0 {
            source
        } else {
            let cellSize = segmentation.offsetCellSize(radius: abs(amount))
            let limit = style == .miter ? miterLimit : 0
            let tolerance = cellSize / 10
            CachedConcreteTransformer(body: source, name: "Cadova.Offset3D", parameters: amount, segmentation, style, limit) { manifold in
                guard let field = MeshOffset.distanceField(for: manifold) else { return manifold }
                let offset = MeshOffset(field: field, amount: amount, style: style, miterLimit: miterLimit, cellSize: cellSize, tolerance: tolerance, segmentation: segmentation)
                return try MeshOffset.manifold(from: offset.run())
            }
            .simplified(maximumThreshold: MeshOffset.simplificationThreshold(forTolerance: tolerance))
        }
    }
}

internal extension MeshOffset {
    /// The exact distance to a solid's surface, or nil for an empty solid
    static func distanceField(for manifold: Manifold) -> MeshDistanceField? {
        let mesh = manifold.meshGL()
        let faces = mesh.triangles.map { ($0.a, $0.b, $0.c) }
        guard !faces.isEmpty else { return nil }
        return MeshDistanceField(vertices: mesh.vertices, faces: faces)
    }

    /// The most a contoured result may be simplified by: enough to merge the many small triangles flat faces and
    /// straight runs come out as, which lie in one plane to rounding error. Simplifying further only coarsens curved
    /// parts, and by far more than the threshold, since each collapse is only checked against the mesh the previous
    /// ones left: on a fillet along a long edge, even a fraction of the tolerance opened gaps many times it.
    static func simplificationThreshold(forTolerance tolerance: Double) -> Double {
        tolerance / 10_000
    }

    /// A solid from a contoured surface
    static func manifold(from result: (vertices: [Vector3D], faces: [Face])) throws -> Manifold {
        guard !result.faces.isEmpty else { return .empty }
        let triangles = result.faces.map { Manifold3D.Triangle($0.0, $0.1, $0.2) }
        return try Manifold(MeshGL(vertices: result.vertices, triangles: triangles))
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

    /// How far a circle of the given radius, segmented this way, strays from its arc: the distance from the middle of
    /// a segment to it
    func sagitta(radius: Double) -> Double {
        radius * (1 - cos(.pi / Double(segmentCount(circleRadius: radius))))
    }
}
