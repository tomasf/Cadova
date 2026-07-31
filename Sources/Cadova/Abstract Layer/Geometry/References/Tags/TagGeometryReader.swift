import Foundation

internal struct TagGeometryReader<Output: Dimensionality>: Geometry {
    let tag: Tag
    let reader: @Sendable ([D3.Geometry]) -> Output.Geometry

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<Output> {
        let geometries = environment.buildResults(for: tag).map {
            $0.transformed(environment.transform.inverse)
        }
        return try await context.buildResult(for: reader(geometries), in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: tag) }
    }
}

public extension Tag {
    /// Reads the individual geometry members associated with this tag and provides them for further composition.
    ///
    /// This is similar to using the tag directly as geometry, except the tagged definitions are passed to the
    /// `reader` closure as separate geometries instead of being unioned first. Each geometry is positioned in the
    /// same coordinate system as a direct tag reference, preserving the world-space transform captured when tagged.
    ///
    /// - Parameter reader: A closure that receives all geometries currently associated with this tag.
    /// - Returns: A geometry object resulting from the `reader` closure.
    func readingMembers<Output: Dimensionality>(
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ members: [D3.Geometry]) -> Output.Geometry
    ) -> Output.Geometry {
        TagGeometryReader(tag: self, reader: reader)
    }

    /// Applies a transform to each individual geometry member associated with this tag and unions the results.
    ///
    /// This is a convenience wrapper around `readingMembers` for the common case where every tagged definition should
    /// be processed independently.
    ///
    /// - Parameter transform: A closure called once for each tagged geometry member.
    /// - Returns: The union of all geometries returned by `transform`.
    func map<Output: Dimensionality>(
        @GeometryBuilder<Output> _ transform: @Sendable @escaping (_ member: D3.Geometry) -> Output.Geometry
    ) -> Output.Geometry {
        readingMembers { members in
            for member in members {
                transform(member)
            }
        }
    }
}
