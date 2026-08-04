import Foundation

public extension GeometryEvaluator {
    /// Returns every surface crossing where `segment` enters or exits `geometry`.
    ///
    /// Each crossing carries its position, surface normal, and parameter along the segment. Crossings
    /// are sorted by ascending ``SurfaceCrossing/distance`` and lie within `0...segment.length`. This
    /// is the evaluator equivalent of ``Geometry3D/readingSurfaces(along:_:)``.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - segment: The segment along which to look for crossings.
    /// - Returns: All crossings within the segment, sorted by distance.
    ///
    func surfaces(of geometry: any Geometry3D, along segment: LineSegment3D) async -> [SurfaceCrossing] {
        await capture(fallback: []) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            let evalResult = try await context.result(for: buildResult.node)
            let hits = evalResult.concrete.rayCast(from: segment.start, to: segment.end)
            return hits.map {
                SurfaceCrossing(hit: $0, origin: segment.start, direction: segment.direction)
            }
        }
    }

    /// Casts a ray forward from `origin` in `direction` and returns every surface crossing on `geometry`.
    ///
    /// The ray extends forward only — surfaces behind `origin` are never reported. Internally the ray
    /// is clipped to a segment long enough to span the geometry's bounding box, so all forward
    /// crossings are returned regardless of how far away the geometry is. This is the evaluator
    /// equivalent of ``Geometry3D/readingSurfaces(from:in:_:)``.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - origin: The starting point of the ray.
    ///   - direction: The direction the ray extends.
    /// - Returns: All forward crossings on `geometry`, sorted by distance. Empty if the geometry is
    ///            empty or the ray misses entirely.
    ///
    func surfaces(of geometry: any Geometry3D, from origin: Vector3D, in direction: Direction3D) async -> [SurfaceCrossing] {
        guard let bounds = await bounds(of: geometry) else { return [] }
        return await surfaces(of: geometry, along: bounds.coveringSegment(from: origin, in: direction))
    }

    /// Returns the first surface crossing on `geometry` within `segment`, or `nil` if there are none.
    ///
    /// Convenience over ``surfaces(of:along:)`` when only the nearest hit is interesting — for
    /// example, finding where a peg lands on a curved surface.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - segment: The segment along which to look for crossings.
    /// - Returns: The nearest crossing within `segment`, or `nil` if none.
    ///
    func firstSurface(of geometry: any Geometry3D, along segment: LineSegment3D) async -> SurfaceCrossing? {
        await surfaces(of: geometry, along: segment).first
    }

    /// Returns the first surface crossing along the ray from `origin` in `direction`, or `nil` if the
    /// ray hits nothing.
    ///
    /// Convenience over ``surfaces(of:from:in:)``. The ray extends forward only.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - origin: The starting point of the ray.
    ///   - direction: The direction the ray extends.
    /// - Returns: The nearest forward crossing, or `nil` if the ray misses.
    ///
    func firstSurface(of geometry: any Geometry3D, from origin: Vector3D, in direction: Direction3D) async -> SurfaceCrossing? {
        await surfaces(of: geometry, from: origin, in: direction).first
    }
}
