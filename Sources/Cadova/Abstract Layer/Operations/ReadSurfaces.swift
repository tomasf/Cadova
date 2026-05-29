import Foundation
import Manifold3D

public extension Geometry3D {
    /// Casts a ray forward from `origin` in `direction` and hands every surface crossing to the reader.
    ///
    /// The ray extends forward only — surfaces behind `origin` are never reported. Internally the
    /// ray is clipped to a segment long enough to cover the geometry's bounding box, so all
    /// forward crossings are returned regardless of how far away the geometry is.
    ///
    /// Crossings are sorted by ascending ``SurfaceCrossing/distance``.
    ///
    /// ```swift
    /// terrain.readingSurfaces(from: [x, y, 100], in: .down) { terrain, crossings in
    ///     terrain.adding {
    ///         for c in crossings {
    ///             Sphere(radius: 0.5).translated(c.position)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - origin: The starting point of the ray.
    ///   - direction: The direction the ray extends.
    ///   - reader: Receives the original geometry and the list of crossings.
    /// - Returns: The geometry produced by `reader`.
    func readingSurfaces<Output: Dimensionality>(
        from origin: Vector3D,
        in direction: Direction3D,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ crossings: [SurfaceCrossing]) -> Output.Geometry
    ) -> Output.Geometry {
        measuring { geometry, measurements in
            guard let bounds = measurements.boundingBox else {
                return reader(geometry, [])
            }
            return geometry.readingSurfaces(along: bounds.coveringSegment(from: origin, in: direction), reader)
        }
    }

    /// Hands every surface crossing inside `segment` to the reader.
    ///
    /// Crossings are sorted by ascending ``SurfaceCrossing/distance`` and lie in `0...segment.length`.
    ///
    /// - Parameters:
    ///   - segment: The segment to query.
    ///   - reader: Receives the original geometry and the list of crossings.
    /// - Returns: The geometry produced by `reader`.
    func readingSurfaces<Output: Dimensionality>(
        along segment: LineSegment3D,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ crossings: [SurfaceCrossing]) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { (manifold: Manifold) in
            let hits = manifold.rayCast(from: segment.start, to: segment.end)
            let direction = segment.direction
            let crossings = hits.map {
                SurfaceCrossing(hit: $0, origin: segment.start, direction: direction)
            }
            return reader(self, crossings)
        }
    }

    /// Casts a ray forward from `origin` in `direction` and hands the first surface crossing
    /// (or `nil` if the ray hits nothing) to the reader.
    func readingFirstSurface<Output: Dimensionality>(
        from origin: Vector3D,
        in direction: Direction3D,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ crossing: SurfaceCrossing?) -> Output.Geometry
    ) -> Output.Geometry {
        readingSurfaces(from: origin, in: direction) { geometry, crossings in
            reader(geometry, crossings.first)
        }
    }

    /// Hands the first surface crossing within `segment` (or `nil` if it doesn't cross anything)
    /// to the reader.
    func readingFirstSurface<Output: Dimensionality>(
        along segment: LineSegment3D,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ crossing: SurfaceCrossing?) -> Output.Geometry
    ) -> Output.Geometry {
        readingSurfaces(along: segment) { geometry, crossings in
            reader(geometry, crossings.first)
        }
    }
}

internal extension BoundingBox3D {
    /// A segment starting at `origin` and extending in `direction` far enough to span this box.
    ///
    /// Picks the AABB corner that maximizes the dot product with `direction` — that's the corner
    /// whose signs along each axis match the direction's. The segment's length is the projected
    /// distance to that corner, padded by a small margin to guarantee any surface at that corner
    /// is hit.
    func coveringSegment(from origin: Vector3D, in direction: Direction3D) -> LineSegment3D {
        let dir = direction.unitVector
        let farCorner = Vector3D(
            dir.x >= 0 ? maximum.x : minimum.x,
            dir.y >= 0 ? maximum.y : minimum.y,
            dir.z >= 0 ? maximum.z : minimum.z
        )
        let projection = (farCorner - origin) ⋅ dir
        let length = max(projection, 0) + 1.0
        return LineSegment3D(from: origin, to: origin + dir * length)
    }
}
