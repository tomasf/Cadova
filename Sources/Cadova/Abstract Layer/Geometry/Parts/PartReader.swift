import Foundation

internal struct PartReader<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let semantic: PartSemantic
    let name: String?
    let reader: @Sendable (Input.Geometry, [String: D3.Geometry]) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)
        let parts = Dictionary(uniqueKeysWithValues: output.elements[PartCatalog.self].parts.compactMap {
            $0.type == semantic && (name == nil || name == $0.name) ? ($0.name, Union($1)) : nil
        })

        return try await context.buildResult(for: reader(output, parts), in: environment)
    }
}

public extension Geometry {
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
        PartReader(body: self, semantic: semantic, name: nil, reader: reader)
    }

    /// Reads a single named part of a given semantic without detaching it, and provides it for further composition.
    ///
    /// This method looks for a part previously marked with `.inPart(named:type:)` that matches both the provided
    /// `semantic` and `name`. Unlike `detachingPart`, it does not remove the part from the input geometry. If a
    /// matching part exists, its geometry is passed to the `reader` closure; otherwise, `nil` is passed.
    ///
    /// Use this to selectively inspect or reuse one specific part while keeping the base geometry intact — for
    /// example, to overlay annotations, apply transforms, or conditionally include the part in derived geometry.
    ///
    /// - Parameters:
    ///   - semantic: The semantic type of the part to read. Defaults to `.solid`.
    ///   - name: The exact name of the part to read.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - part: The combined geometry of the named part, or `nil` if the part is not present.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingPart<Output: Dimensionality>(
        ofType semantic: PartSemantic = .solid,
        named name: String,
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ part: D3.Geometry?) -> Output.Geometry
    ) -> Output.Geometry {
        PartReader(body: self, semantic: semantic, name: name) { input, parts in
            reader(input, parts.first?.value)
        }
    }
}
