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

    /// Whether the ray or segment is moving into or out of the solid at this crossing.
    public let transition: Transition

    /// The direction a ray or segment passes through a surface.
    public enum Transition: Sendable, Hashable, Codable, CaseIterable {
        /// The ray moves from the outside to the inside of the solid, meaning the surface normal
        /// opposes the direction of travel.
        case entering
        /// The ray moves from the inside to the outside of the solid, meaning the surface normal
        /// points along the direction of travel.
        case exiting
    }

    internal init(position: Vector3D, normal: Direction3D, distance: Double, transition: Transition) {
        self.position = position
        self.normal = normal
        self.distance = distance
        self.transition = transition
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
            transition: (normal.unitVector ⋅ dir) < 0 ? .entering : .exiting
        )
    }
}

internal extension Sequence<SurfaceCrossing> {
    /// The first crossing with the given transition, or the first crossing of either kind if
    /// `transition` is `nil`.
    func first(with transition: SurfaceCrossing.Transition?) -> SurfaceCrossing? {
        first { transition == nil || $0.transition == transition }
    }
}
