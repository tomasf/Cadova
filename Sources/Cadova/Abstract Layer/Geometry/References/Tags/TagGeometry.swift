internal struct TagGeometry: Geometry {
    let body: any Geometry3D
    let tag: Tag

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D3> {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let globalResult = bodyResult.modifyingNode { .transform($0, transform: environment.transform) }

        return bodyResult.modifyingElement(ReferenceState.self) {
            $0.define(tag: tag, as: globalResult)
        }
    }
}

public extension Geometry3D {
    /// Attaches a tag to this geometry, allowing it to be referenced elsewhere in the same model.
    ///
    /// The tagged geometry is recorded in its **current** coordinate system, meaning the world-space position
    /// it has at the point where `tagged(_:)` is called — including any transforms applied to it earlier in
    /// the chain. References to this tag later reproduce the geometry at that same world position.
    ///
    /// ```swift
    /// // The tagged box is captured at world (5...6) — the translation is part of the anchor.
    /// Box(1).translated(x: 5).tagged(myTag)
    /// ```
    ///
    /// See ``Tag`` for how references behave when transforms are applied to them.
    ///
    /// - Multiple definitions:
    ///   - You can tag multiple geometries with the same `Tag`. When that tag is referenced, all tagged geometries are
    ///     merged (unioned) into a single result.
    ///
    /// - Parameter tag: The `Tag` to attach to this geometry.
    /// - Returns: A geometry that records the association with the provided tag.
    ///
    func tagged(_ tag: Tag) -> any Geometry3D {
        TagGeometry(body: self, tag: tag)
    }
}
