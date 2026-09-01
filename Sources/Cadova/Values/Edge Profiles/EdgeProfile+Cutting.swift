import Foundation

internal extension Geometry3D {
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        with shape: any Geometry2D,
        at plane: Plane
    ) -> any Geometry3D {
        CuttingEdgeProfile(source: self, edgeProfile: edgeProfile, shape: shape, plane: plane)
    }
}

private struct CuttingEdgeProfile: Geometry3D {
    let source: any Geometry3D
    let edgeProfile: EdgeProfile
    let shape: any Geometry2D
    let plane: Plane

    var body: any Geometry3D {
        @Environment(\.operation) var operation
        // Snapshotted into a plain `let`: `operation` is read here, but used inside the `withEnvironment`
        // closure below, which `EnvironmentModifier` stores and invokes later — potentially from deep
        // inside an already-flipped `.subtracting` branch. `@Environment`'s wrappedValue re-reads the
        // ambient environment on every access rather than snapshotting, so referencing `operation` itself
        // (instead of this pinned copy) inside that closure would silently pick up the wrong value.
        let pinnedOperation = operation

        // The traced slice describes the source body, so it must keep the source operation even though the
        // swept profile itself is evaluated in the subtraction branch.
        let sourceShape = shape.withEnvironment { $0.withOperation(pinnedOperation) }

        // Edge profiling works in plane-local coordinates, but the profiled geometry must still build in source space.
        ApplyTransform(
            body: ApplyTransform(body: source, transform: plane.transform.inverse, transformEnvironment: false)
                .subtracting(edgeProfile.followingEdge(of: sourceShape, type: .subtraction)),
            transform: plane.transform,
            transformEnvironment: false
        )
    }
}

public extension Geometry3D {
    /// Cuts (subtracts) an edge profile along the edges where the geometry intersects a side of its bounds.
    ///
    /// The profile is swept along the slice of the shape at the given side/offset and removed
    /// from the host geometry, producing exterior features like chamfers and fillets.
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile (e.g. `.top`, `.right`).
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///             Positive values move toward the positive axis direction.
    /// - Returns: A new geometry with the profile cut into the selected side.
    ///
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            measuringBounds { _, selfBounds in
                let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
                let slicedShape = sliced(along: plane.offset(-profileBounds.size.y))
                    .ifEmpty { sliced(along: plane.offset(-1e-6)) }
                cuttingEdgeProfile(edgeProfile, with: slicedShape, at: plane)
            }
        }
    }

    /// Cuts (subtracts) an edge profile using a custom 2D cross‑section in place of the auto‑sliced one.
    ///
    /// Use this when you want to profile along a specific cross‑section rather than the geometry’s
    /// actual slice at the profiling plane (for example, to keep a constant-width path).
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile.
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///   - shape: A builder that provides the cross‑section path to follow.
    /// - Returns: A new geometry with the profile cut along the provided cross‑section.
    ///
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0,
        @GeometryBuilder2D using shape: @escaping @Sendable () -> any Geometry2D
    ) -> any Geometry3D {
        measuringBounds { _, selfBounds in
            let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
            cuttingEdgeProfile(edgeProfile, with: side.footprintShape(shape()), at: plane)
        }
    }
}
