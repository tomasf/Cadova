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
/// ## World-anchored references
///
/// A tag reference reproduces its geometry at the world-space position it had at the time of tagging,
/// **regardless of where the reference appears in the tree**. This is the central property of tags:
/// they are anchored to a captured world position, so transforms applied to ancestor geometry around
/// a reference do not move it.
///
/// ```swift
/// let part = Tag()
/// let model = Box(1)
///     .translated(x: 5)         // tagged box is at world (5...6)
///     .tagged(part)
///     .adding {
///         // The Union below would normally translate everything inside it by +100,
///         // but the reference stays anchored at its captured world position (5...6).
///         Union { part }.translated(x: 100)
///     }
/// ```
///
/// ## Transforms applied directly to a reference
///
/// Transforms chained directly onto a tag reference *do* move it. They are applied in the
/// **local coordinate frame** at the call site — the same way transforms on regular geometry behave:
///
/// ```swift
/// part.translated(x: 10)              // reference moves +10 along local X
/// part.translated(x: 10).rotated(...) // chained transforms compose in local frame
/// ```
///
/// If the reference sits inside a rotated parent, the direct transforms see that rotation as the
/// local frame, so `.translated(x: 10)` moves along the parent's local X — not world X.
///
/// The distinction is:
/// - **Direct chains** on a tag/reference (via `translated`, `rotated`, etc.) compose into a single
///   transform and move the reference, in the local frame.
/// - **Outer wrappers** (transforms applied to a parent containing a reference) flow through the
///   environment and are cancelled, preserving the world anchor.
///
/// This means `tag.translated(x: 10)` translates; but `Group { tag }.translated(x: 10)` does not.
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

/// References geometry previously associated with this tag.
///
/// When evaluated, this returns the geometry tagged with the same `Tag`, positioned at the same world-space
/// location and orientation it had at the time of tagging. If the tag was applied to multiple geometries,
/// the referenced result is the merged (unioned) combination of all of them.
///
/// Transforms applied to ancestor geometry around the reference are cancelled by the world-anchor logic,
/// while transforms chained directly onto the reference (via `translated`, `rotated`, etc.) move it
/// relative to its anchor. See ``Tag`` for a full discussion of these two cases.
///
/// - Undefined tags:
///   - If the tag has not yet been defined in the model, this produces an empty geometry placeholder and marks the
///     tag as “used” so it can be resolved in a later pass. If the tag is still undefined at the top level, a
///     warning is printed.
///
extension Tag: Geometry {
    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> D3._BuildResult {
        let output = Union {
            environment.buildResults(for: self)
        }.transformed(environment.transform.inverse)

        return try await context.buildResult(for: output, in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: self) }
    }

    /// Applies a transform to this tag reference.
    ///
    /// Transforms chained directly onto a tag reference (e.g. `tag.translated(x: 10)`) are applied
    /// to the world-anchored geometry, so they move it as expected. Transforms applied to a parent
    /// geometry that contains a tag reference still flow through the environment and are cancelled
    /// by the world-anchor logic, preserving the captured position.
    ///
    public func transformed(_ transform: Transform3D) -> any Geometry3D {
        if transform.isIdentity {
            return self
        }
        return TagReference(tag: self, transform: transform)
    }
}

/// A tag reference with applied modifications.
///
/// Currently this carries an explicit transform; additional kinds of per-reference modifications
/// (e.g. material or color overrides) can be added here without affecting `Tag`'s identity semantics.
///
internal struct TagReference: Geometry {
    let tag: Tag
    let transform: Transform3D

    func transformed(_ additional: Transform3D) -> any Geometry3D {
        if additional.isIdentity {
            return self
        }
        return TagReference(tag: tag, transform: transform.transformed(additional))
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let output = Union {
            environment.buildResults(for: tag)
        }
        .transformed(environment.transform.inverse)
        .transformed(transform)

        return try await context.buildResult(for: output, in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: tag) }
    }
}

public extension Geometry {
    /// Removes tag definitions recorded within this geometry.
    ///
    /// Use this method to discard tag definitions captured in this subtree so that they are no longer
    /// visible to tag references placed outside of it. This is useful when tags are used locally for
    /// internal composition and should not be exposed upstream.
    ///
    /// - Parameter tag: A specific tag whose definitions should be removed. If `nil`, all tag
    ///   definitions recorded in this subtree are removed.
    /// - Returns: A geometry with the matching tag definitions removed.
    ///
    func removingTagDefinitions(for tag: Tag? = nil) -> D.Geometry {
        modifyingResult(ReferenceState.self) { state in
            state.removeTagDefinitions(for: tag)
        }
    }
}
