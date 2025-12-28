import Foundation

internal struct PartDetachment<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let part: Part
    let reader: @Sendable (Input.Geometry, D3.Geometry?) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)

        var detachedPart: D3.BuildResult?
        let newOutput = output.modifyingElement(PartCatalog.self) {
            detachedPart = $0.detach(part)
        }

        let outputGeometry = reader(newOutput, detachedPart)
        return try await context.buildResult(for: outputGeometry, in: environment)
    }
}

public extension Geometry {
    /// Extracts the specified part from the current geometry and allows further manipulation.
    ///
    /// This method detaches a part previously marked with `.inPart(_:)`. The detached part is removed
    /// from the input geometry and passed to the `reader` closure for further use or composition.
    /// If no matching part is found, `part` will be `nil`.
    ///
    /// This is useful when you want to extract, reuse, or reposition specific parts of a model independently,
    /// such as rearranging multi-part assemblies or isolating individual components. The detached part is no
    /// longer included in the final output unless it is explicitly reattached or otherwise incorporated again.
    ///
    /// - Parameters:
    ///   - part: The part to detach.
    ///   - reader: A closure that receives:
    ///       - geometry: The original geometry with the matching part removed.
    ///       - part: The detached part's combined geometry, or `nil` if no matching part exists.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func detachingPart<Output: Dimensionality>(
        _ part: Part,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: D.Geometry, _ part: (any Geometry3D)?) -> Output.Geometry
    ) -> Output.Geometry {
        PartDetachment(body: self, part: part, reader: reader)
    }

    /// Extracts a named part from the current geometry and allows further manipulation.
    ///
    /// This method detaches a part previously marked with `.inPart(named:type:)` that matches both the provided
    /// `partName` and `type`. The detached part is removed from the input geometry and passed to the
    /// `reader` closure for further use or composition. If no matching part is found, `part` will be `nil`.
    ///
    /// This is useful when you want to extract, reuse, or reposition specific parts of a model independently,
    /// such as rearranging multi-part assemblies or isolating individual components. The detached part is no longer included in the final output unless it is explicitly reattached or otherwise incorporated again.
    ///
    /// - Parameters:
    ///   - partName: The exact name of the part to detach.
    ///   - type: The semantic of the part to detach (e.g., `.solid`, `.visual`, `.context`). Defaults to `.solid`.
    ///   - reader: A closure that receives:
    ///       - geometry: The original geometry with the matching part removed.
    ///       - part: The detached part's combined geometry, or `nil` if no matching part exists.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func detachingPart<Output: Dimensionality>(
        named partName: String,
        ofType type: PartSemantic = .solid,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: D.Geometry, _ part: (any Geometry3D)?) -> Output.Geometry
    ) -> Output.Geometry {
        PartDetachment(body: self, part: .named(partName, semantic: type), reader: reader)
    }
}
