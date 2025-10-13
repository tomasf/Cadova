import Foundation

internal struct PartDetachment<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let partName: String
    let reader: @Sendable (Input.Geometry, D3.Geometry?) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)

        var part: D3.BuildResult?
        let newOutput = output.modifyingElement(PartCatalog.self) {
            part = $0.detachPart(named: partName)
        }

        let outputGeometry = reader(newOutput, part)
        return try await context.buildResult(for: outputGeometry, in: environment)
    }
}

internal struct PartReader<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let semantic: PartSemantic
    let reader: @Sendable (Input.Geometry, [String: D3.Geometry]) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)
        let parts = Dictionary(uniqueKeysWithValues: output.elements[PartCatalog.self].parts.compactMap {
            $0.type == semantic ? ($0.name, Union($1)) : nil
        })

        return try await context.buildResult(for: reader(output, parts), in: environment)
    }
}

public extension Geometry {
    /// Extracts a named part from the current geometry and allows further manipulation.
    ///
    /// This method detaches a part previously marked with `.inPart(named:)`. The detached part is removed from the
    /// input geometry, and passed to the given closure for further use or combination. If no matching part is found,
    /// `part` will be `nil`.
    ///
    /// This is useful when you want to extract, reuse, or reposition specific parts of a model independently, such as
    /// rearranging multi-part assemblies or isolating individual components.
    ///
    /// The detached part is no longer included in the final 3MF output unless it is reattached.
    ///
    /// - Parameters:
    ///   - partName: The name of the part to detach.
    ///   - reader: A closure that receives the original geometry (with the part removed) and the detached
    ///     part (or `nil`), returning new geometry.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func detachingPart<Output: Dimensionality>(
        named partName: String,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: D.Geometry, _ part: (any Geometry3D)?) -> Output.Geometry
    ) -> Output.Geometry {
        PartDetachment(body: self, partName: partName, reader: reader)
    }

    /// Reads parts of a given semantic without detaching them, and provides them for further composition.
    ///
    /// This method scans the current geometry for parts previously marked with `.inPart(named:type:)` that match
    /// the specified semantic (e.g. `.solid`, `.visual`, `.context`). Unlike `detachingPart`, this does not remove
    /// any parts from the input geometry. Instead, all matching parts are collected and provided to the `reader`
    /// closure as a dictionary keyed by part name.
    ///
    /// Use this when you want to inspect or reuse parts while keeping the original geometry intact — for example,
    /// to overlay, transform, or selectively include parts in additional structures.
    ///
    /// - Parameters:
    ///   - semantic: The semantic type of parts to read. Defaults to `.solid`.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - parts: A dictionary mapping part names to their combined geometries for the given semantic.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingParts<Output: Dimensionality>(
        ofType semantic: PartSemantic = .solid,
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ parts: [String: D3.Geometry]) -> Output.Geometry
    ) -> Output.Geometry {
        PartReader(body: self, semantic: semantic, reader: reader)
    }
}
