import Foundation
import Manifold3D

/// A single point where a ray or line segment crosses one of a model's surfaces.
///
/// Returned by `Geometry3D.readingSurfaces(from:in:_:)` and `readingSurfaces(along:_:)`.
/// Crossings are ordered by ascending ``distance`` from the ray's origin (or the segment's start).
public struct SurfaceCrossing: Sendable, Hashable, Codable {
    /// The world-space position where the ray or segment crosses the surface.
    public let position: Vector3D

    /// The outward surface normal at the crossing.
    public let normal: Direction3D

    /// Distance from the ray's origin (or the segment's `start`), measured along the direction.
    /// Always non-negative.
    public let distance: Double

    /// `true` if the ray or segment is moving from the outside to the inside of the solid at this
    /// crossing — i.e. the surface normal opposes the direction of travel. `false` for an exit.
    public let entersSolid: Bool

    internal init(position: Vector3D, normal: Direction3D, distance: Double, entersSolid: Bool) {
        self.position = position
        self.normal = normal
        self.distance = distance
        self.entersSolid = entersSolid
    }

    /// Builds a crossing from a Manifold ray hit, expressing the hit's parametric distance in
    /// terms of `origin` and `direction` and recording whether the ray enters or exits the solid.
    internal init(hit: Manifold3D.RayHit<Vector3D>, origin: Vector3D, direction: Direction3D) {
        let dir = direction.unitVector
        let normal = Direction3D(hit.normal)
        self.init(
            position: hit.position,
            normal: normal,
            distance: (hit.position - origin) ⋅ dir,
            entersSolid: (normal.unitVector ⋅ dir) < 0
        )
    }
}
