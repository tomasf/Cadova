import Foundation

public extension Geometry {
    /// Places this geometry at the transforms recorded by an anchor defined elsewhere.
    ///
    /// Use this to position and orient a geometry so that its origin is placed at each world‑space
    /// transform captured by the specified anchor.
    ///
    /// - Behavior:
    ///   - If the anchor has been defined multiple times, the geometry is duplicated and instanced
    ///     at each recorded world transform, producing one instance per definition.
    ///   - If the anchor has no definitions available by the time the model is fully built, no
    ///     instances are produced and a warning is printed.
    ///
    /// - Parameter anchor: The `Anchor` whose recorded world‑space transforms should be applied to
    ///   this geometry.
    /// - Returns: A modified version of the geometry, placed and oriented at each of the anchor’s
    ///   recorded transforms.
    ///
    func anchored(to anchor: Anchor) -> D.Geometry {
        readEnvironment { environment in
            modifyingResult(ReferenceState.self) { body, referenceState in
                let reset = environment.transform.inverse
                let globalTransforms = referenceState.read(anchor: anchor)
                    .union(environment.transforms(for: anchor))
                let localTransforms: [D.Transform] = globalTransforms.map {
                    D.Transform($0.concatenated(with: reset))
                }

                body.distributed(at: localTransforms)
            }
        }
    }

    /// Removes anchor definitions recorded within this geometry.
    ///
    /// Use this method to discard anchor definitions captured in this subtree so that they are no
    /// longer visible to `anchored(to:)` calls placed outside of it. This is useful when anchors
    /// are used locally for internal placements and should not be exposed upstream.
    ///
    /// - Parameter anchor: A specific anchor whose definitions should be removed. If `nil`, all
    ///   anchor definitions recorded in this subtree are removed.
    /// - Returns: A geometry with the matching anchor definitions removed.
    ///
    func removingAnchorDefinitions(for anchor: Anchor? = nil) -> D.Geometry {
        modifyingResult(ReferenceState.self) { state in
            state.removeAnchorDefinitions(for: anchor)
        }
    }
}

public extension Anchor {
    /// Reads the world-space transforms recorded for this anchor and provides them for further composition.
    ///
    /// This is similar to ``Geometry/anchored(to:)``, except the recorded transforms are passed to the
    /// `reader` closure as a list of values instead of being used to distribute a fixed body. Use this
    /// when you need the transforms themselves — for manual calculations, building geometry whose
    /// structure depends on the transforms, or producing different geometry per transform.
    ///
    /// Each transform is delivered in the local coordinate frame at the call site, matching the
    /// convention used by ``Geometry/anchored(to:)``.
    ///
    /// - Important: The closure may be invoked more than once. When an anchor is defined elsewhere
    ///   in the tree (e.g. in a sibling branch of a union), an initial evaluation pass runs the
    ///   closure before those definitions are visible — often with an empty transform list — and a
    ///   later pass re-runs it with the full set once the definitions have been propagated. Only the
    ///   geometry returned by the final invocation contributes to the result, so the closure should
    ///   be a pure function of its inputs and not rely on side effects.
    ///
    /// - Parameter reader: A closure that receives the anchor's recorded transforms.
    /// - Returns: A geometry object resulting from the `reader` closure.
    func readingTransforms<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping (_ transforms: [D.Transform]) -> D.Geometry
    ) -> D.Geometry {
        AnchorTransformReader(anchor: self, reader: reader)
    }
}

internal struct AnchorTransformReader<Output: Dimensionality>: Geometry {
    let anchor: Anchor
    let reader: @Sendable ([Output.Transform]) -> Output.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<Output> {
        let reset = environment.transform.inverse
        let localTransforms: [Output.Transform] = environment.transforms(for: anchor).map {
            Output.Transform($0.concatenated(with: reset))
        }
        return try await context.buildResult(for: reader(localTransforms), in: environment)
            .modifyingElement(ReferenceState.self) { $0.markUsed(anchor: anchor) }
    }
}
