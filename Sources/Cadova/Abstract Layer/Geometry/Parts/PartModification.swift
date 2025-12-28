import Foundation

internal struct PartModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let predicate: @Sendable (Part) -> Bool
    let modifier: @Sendable (any Geometry3D, Part) -> any Geometry3D

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await context.buildResult(for: body, in: environment)

        return try await output.modifyingElement(PartCatalog.self) {
            PartCatalog(parts: try await Dictionary(uniqueKeysWithValues: $0.parts.asyncCompactMap { catalogPart, results in
                guard predicate(catalogPart) else { return (catalogPart, results) }

                let buildResult = try await context.buildResult(for: modifier(Union(results), catalogPart), in: environment)
                if buildResult.node.isEmpty {
                    return nil
                } else {
                    return (catalogPart, [buildResult])
                }
            }))
        }
    }
}

public extension Geometry {
    /// Applies a transformation to the specified part.
    ///
    /// This method finds a part previously marked with `.inPart(_:)` and passes its geometry to the
    /// `reader` closure. The closure should return the modified geometry for that part. The modified
    /// part replaces the original in the catalog; the base geometry is otherwise preserved.
    ///
    /// Use this to adjust or augment a part - for example, to recolor, add features, apply transforms,
    /// or otherwise post-process the part before exporting a multi-part model.
    ///
    /// - Parameters:
    ///   - part: The part to modify.
    ///   - reader: A closure that receives the 3D geometry of the part.
    ///     The closure should return new 3D geometry to replace the original part in the catalog.
    /// - Returns: A geometry that preserves the base model but replaces the specified part with the closure's result.
    ///
    func modifyingPart(
        _ part: Part,
        @GeometryBuilder<D3> reader: @Sendable @escaping (_ partGeometry: any Geometry3D) -> any Geometry3D
    ) -> D.Geometry {
        PartModifier(body: self, predicate: { $0 == part }) { geometry, _ in
            reader(geometry)
        }
    }

    /// Applies a transformation to each part of the specified semantic.
    ///
    /// This method locates parts that match the given semantic (such as `.solid`, `.visual`, or `.context`)
    /// and passes each part's geometry along with the part itself to the `reader` closure. The closure should
    /// return the modified geometry for that part. The resulting modified parts replace the originals in the
    /// model; the base geometry is otherwise preserved.
    ///
    /// Use this to uniformly adjust or augment parts - for example, to recolor, add features, apply transforms,
    /// or otherwise post-process parts before exporting a multi-part model.
    ///
    /// - Parameters:
    ///   - type: The semantic of parts to modify. Defaults to `.solid`.
    ///   - reader: A closure that receives:
    ///       - partGeometry: The combined 3D geometry of a part matching the semantic.
    ///       - part: The part being modified.
    ///     The closure should return new 3D geometry to replace the original part in the catalog.
    ///
    func modifyingParts(
        ofType type: PartSemantic = .solid,
        @GeometryBuilder<D3> reader: @Sendable @escaping (_ partGeometry: any Geometry3D, _ part: Part) -> any Geometry3D
    ) -> D.Geometry {
        PartModifier(body: self, predicate: { $0.semantic == type }, modifier: reader)
    }

    /// Removes the specified part from the part catalog.
    ///
    /// This does not alter the base geometry of the receiver; it only removes the matching entry
    /// from the catalog created via `.inPart(_:)`.
    ///
    /// - Parameter part: The part to remove.
    /// - Returns: A geometry that preserves the base model but omits the specified part from the catalog.
    ///
    func removingPart(_ part: Part) -> D.Geometry {
        PartModifier(body: self, predicate: { $0 == part }) { _, _ in Empty() }
    }

    /// Removes all parts of the specified semantic from the part catalog.
    ///
    /// This does not alter the base geometry of the receiver; it only removes matching entries
    /// from the catalog.
    ///
    /// - Parameter type: The semantic of parts to remove. Defaults to `.solid`.
    /// - Returns: A geometry that preserves the base model but omits the matching parts from the catalog.
    ///
    func removingParts(ofType type: PartSemantic = .solid) -> D.Geometry {
        PartModifier(body: self, predicate: { $0.semantic == type }) { _, _ in Empty() }
    }
}
