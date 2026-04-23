import Foundation

/// A value used to identify and later reference geometry by “tagging” it.
///
/// Tags provide a way to give geometry an identity that can be referenced elsewhere in the same model.
/// You create a tag once (optionally with a human-readable label for debugging) and then apply it to any
/// 3D geometry. Later, you can reference the same tag to retrieve the tagged geometry at the same
/// world-space location and orientation it had when it was originally defined.
///
/// - Multiple definitions:
///   - A tag can be applied to multiple geometries. When referenced, all definitions are merged (unioned) together.
///     This allows you to collect or aggregate geometry across different parts of your model under the same tag.
///
/// - Undefined tags:
///   - Referencing a tag that has not yet been defined produces an empty geometry placeholder and marks the tag as
///     “used” in the current tree so it can be resolved in a later pass. If a tag remains unresolved at the top level,
///     a warning is printed.
///
/// - Coordinate systems:
///   - Referencing a tag reproduces the tagged geometry at the same world-space location and orientation it had at the
///     time of tagging. This means the geometry appears where you would expect, relative to the current transform context.
///
public struct Tag: Hashable, Sendable {
    internal let id = UUID()
    internal let label: String?

    /// Creates a new tag.
    ///
    /// - Parameter label: An optional label for debugging and diagnostics (e.g., undefined tag warnings).
    public init(_ label: String? = nil) {
        self.label = label
    }

    public var description: String {
        if let label {
            "Tag \"\(label)\" (\(id))"
        } else {
            "Tag \(id)"
        }
    }
}

public extension Geometry3D {
    /// Attaches a tag to this geometry, allowing it to be referenced elsewhere in the same model.
    ///
    /// The tagged geometry is recorded in its current coordinate system so that later references to the tag reproduce
    /// the same geometry at the same world-space location and orientation.
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

/// References geometry previously associated with this tag.
///
/// When evaluated, this returns the geometry tagged with the same `Tag`, positioned at the same world-space
/// location and orientation it had at the time of tagging. If the tag was applied to multiple geometries,
/// the referenced result is the merged (unioned) combination of all of them.
///
/// - Undefined tags:
///   - If the tag has not yet been defined in the model, this produces an empty geometry placeholder and marks the
///     tag as “used” so it can be resolved in a later pass. If the tag is still undefined at the top level, a
///     warning is printed.
///
extension Tag: Geometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let output = Union {
            environment.buildResults(for: self)
        }.transformed(environment.transform.inverse)

        return try await context.buildResult(for: output, in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: self) }
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

internal struct TagGeometryReader<Output: Dimensionality>: Geometry {
    let tag: Tag
    let reader: @Sendable ([D3.Geometry]) -> Output.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let geometries = environment.buildResults(for: tag).map {
            $0.transformed(environment.transform.inverse)
        }
        return try await context.buildResult(for: reader(geometries), in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: tag) }
    }
}

internal struct TagGeometry: Geometry {
    let body: any Geometry3D
    let tag: Tag

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let globalResult = bodyResult.modifyingNode { .transform($0, transform: environment.transform) }

        return bodyResult.modifyingElement(ReferenceState.self) {
            $0.define(tag: tag, as: globalResult)
        }
    }
}
