import Foundation

internal extension Geometry3D {
    func formingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        with shape: any Geometry2D,
        at plane: Plane
    ) -> any Geometry3D {
        transformed(plane.transform.inverse)
            .adding(edgeProfile.followingEdge(of: shape, type: .addition))
            .transformed(plane.transform)
    }
}

public extension Geometry3D {
    /// Forms (adds) an edge profile along the edges where the geometry intersects a side of its bounds.
    ///
    /// The profile is swept along the slice of the shape at the given side/offset and added
    /// to the host geometry, producing interior build‑ups like coves, beads, or decorative lips.
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile (e.g. `.bottom`, `.left`).
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///             Positive values move toward the positive axis direction.
    /// - Returns: A new geometry with the profile formed on the selected side.
    ///
    func formingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            measuringBounds { _, selfBounds in
                let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
                let slicedShape = sliced(along: plane.offset(-profileBounds.size.y))
                    .ifEmpty { sliced(along: plane) }
                formingEdgeProfile(edgeProfile, with: slicedShape, at: plane)
            }
        }
    }

    /// Forms (adds) an edge profile using a custom 2D cross‑section in place of the auto‑sliced one.
    ///
    /// Use this when you want to profile along a specific cross‑section rather than the geometry’s
    /// actual slice at the profiling plane.
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile.
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///   - shape: A builder that provides the cross‑section path to follow.
    /// - Returns: A new geometry with the profile formed along the provided cross‑section.
    ///
    func formingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0,
        @GeometryBuilder2D using shape: @escaping @Sendable () -> any Geometry2D
    ) -> any Geometry3D {
        measuringBounds { _, selfBounds in
            let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
            formingEdgeProfile(edgeProfile, with: shape(), at: plane)
        }
    }
}
