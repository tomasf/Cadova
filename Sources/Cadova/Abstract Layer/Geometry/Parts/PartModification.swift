import Foundation

internal struct PartModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let semantic: PartSemantic
    let name: String?
    let modifier: @Sendable (any Geometry3D, String) -> any Geometry3D

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)

        return try await output.modifyingElement(PartCatalog.self) {
            PartCatalog(parts: try await Dictionary(uniqueKeysWithValues: $0.parts.asyncCompactMap {
                guard $0.type == semantic else { return ($0, $1) }
                if let name {
                    guard $0.name == name else { return ($0,$1) }
                }

                let buildResult = try await context.buildResult(for: modifier(Union($1), $0.name), in: environment)
                if buildResult.node.isEmpty {
                    return nil
                } else {
                    return ($0, [buildResult])
                }
            }))
        }
    }
}

public extension Geometry {
    /// Applies a transformation to each part of the specified semantic.
    ///
    /// This method locates parts previously marked with `.inPart(named:type:)` that match the given semantic
    /// (such as `.solid`, `.visual`, or `.context`) and passes each part’s geometry along with its name to the
    /// `reader` closure. The closure should return the modified geometry for that part. The resulting modified
    /// parts replace the originals in the model; the base geometry is otherwise preserved.
    ///
    /// Use this to uniformly adjust or augment parts - for example, to recolor, add features, apply transforms,
    /// or otherwise post-process parts before exporting a multi-part model.
    ///
    /// - Parameters:
    ///   - semantic: The semantic of parts to modify. Defaults to `.solid`.
    ///   - reader: A closure that receives:
    ///       - part: The combined 3D geometry of a part matching `semantic`.
    ///       - name: The part’s name.
    ///     The closure should return new 3D geometry to replace the original part in the catalog.
    ///
    func modifyingParts(
        ofType semantic: PartSemantic = .solid,
        @GeometryBuilder<D3> reader: @Sendable @escaping (_ part: any Geometry3D, _ name: String) -> any Geometry3D
    ) -> D.Geometry {
        PartModifier(body: self, semantic: semantic, name: nil, modifier: reader)
    }

    /// Applies a transformation to a single named part of the specified semantic.
    ///
    /// This method finds exactly one part previously marked with `.inPart(named:type:)` that matches both
    /// the provided `semantic` and `name`, and passes that part’s geometry to the
    /// `reader` closure. The closure should return the modified geometry for that part. Only the targeted
    /// part is replaced in the catalog; the base geometry and other parts remain unchanged.
    ///
    /// - Parameters:
    ///   - semantic: The semantic of the part to modify. Defaults to `.solid`.
    ///   - name: The exact name of the part to modify.
    ///   - reader: A closure that receives the 3D geometry of the named part.
    ///     The closure should return new 3D geometry to replace the original part in the catalog.
    /// - Returns: A geometry that preserves the base model but replaces the specified part with the closure’s result.
    ///
    func modifyingPart(
        ofType semantic: PartSemantic = .solid,
        named name: String,
        @GeometryBuilder<D3> reader: @Sendable @escaping (_ part: any Geometry3D) -> any Geometry3D
    ) -> D.Geometry {
        PartModifier(body: self, semantic: semantic, name: name) { geometry, _ in
            reader(geometry)
        }
    }

    /// Removes all parts of the specified semantic from the part catalog.
    ///
    /// This does not alter the base geometry of the receiver; it only removes matching entries
    /// from the catalog created via `.inPart(named:type:)`.
    ///
    /// - Parameter semantic: The semantic of parts to remove. Defaults to `.solid`.
    /// - Returns: A geometry that preserves the base model but omits the matching parts from the catalog.
    ///
    func removingParts(ofType semantic: PartSemantic = .solid) -> D.Geometry {
        PartModifier(body: self, semantic: semantic, name: nil) { _, _ in Empty() }
    }

    /// Removes a single named part of the specified semantic from the part catalog.
    ///
    /// This targets a specific part previously created with `.inPart(named:type:)` and removes only
    /// that entry. The underlying base geometry remains unchanged.
    ///
    /// - Parameters:
    ///   - semantic: The semantic of the part to remove. Defaults to `.solid`.
    ///   - name: The exact name of the part to remove.
    /// - Returns: A geometry that preserves the base model but omits the specified part from the catalog.
    ///
    func removingPart(ofType semantic: PartSemantic = .solid, named name: String) -> D.Geometry {
        PartModifier(body: self, semantic: semantic, name: name) { _, _ in Empty() }
    }
}
