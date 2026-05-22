import Foundation

/// A value used to mark coordinate systems that can be referenced elsewhere in a model.
///
/// Anchors provide a way to capture a transformation state at one location in your geometry tree
/// and later place other geometry at that same world-space position and orientation. This is useful
/// for attaching parts together, such as placing screws in predefined holes or mounting components
/// at specific locations.
///
/// You create an anchor once (optionally with a human-readable label for debugging) and then define
/// it on geometry using `definingAnchor(_:at:offset:pointing:rotated:)`. Later, you can
/// use `anchored(to:)` to place other geometry at the recorded transforms.
///
/// - Multiple definitions:
///   - An anchor can be defined multiple times across a geometry tree. Each definition records a
///     separate world transform. When you call `anchored(to:)`, the geometry is duplicated at each
///     recorded location and orientation.
///
/// - Undefined anchors:
///   - Referencing an anchor that has no definitions produces no geometry and prints a warning when
///     the model is fully built.
///
public struct Anchor: Hashable, Sendable, CustomStringConvertible {
    internal let id = UUID()
    internal let label: String?

    /// Creates a new anchor.
    ///
    /// - Parameter label: An optional label for debugging and diagnostics (e.g., undefined anchor warnings).
    public init(_ label: String? = nil) {
        self.label = label
    }

    public var description: String {
        if let label {
            "Anchor \"\(label)\" (\(id))"
        } else {
            "Anchor \(id)"
        }
    }
}

public extension Geometry3D {
    /// Defines an anchor point.
    ///
    /// Use this method to mark the current coordinate system as an anchor. The anchor captures the current
    /// transformation state and applies the provided transform. The resulting world transform is recorded for
    /// later use by `anchored(to:)`.
    ///
    /// - Important:
    ///   - The same `Anchor` can be defined multiple times across a geometry tree. Each definition records a separate
    ///     world transform. When you later call `anchored(to:)` with that anchor, the geometry is duplicated, one
    ///     instance per definition, at the same world-space locations and orientations as captured by the anchor.
    ///   - If an anchor is referenced but has no definitions by the time the model is fully built, a warning is
    ///     printed.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - transform: A transform applied relative to the current transformation state; the resulting world transform
    ///     is recorded as an anchor definition.
    /// - Returns: The geometry with a defined anchor.
    ///
    func definingAnchor(_ anchor: Anchor, transform: Transform3D) -> any Geometry3D {
        definingAnchor(anchor, alignment: .none, transform: transform)
    }

    /// Defines an anchor point.
    ///
    /// Use this method to mark a specific coordinate system as an anchor. The anchor captures the current
    /// transformation state, optionally applying an additional alignment, offset, direction, and rotation around the
    /// direction vector. The resulting world transform is recorded for later use by `anchored(to:)`.
    ///
    /// The applied transform is constructed by:
    /// 1) applying the specified alignment (if any),
    /// 2) translating by `offset`,
    /// 3) rotating around Z by `rotation`,
    /// 4) rotating from `.up` to `direction`.
    ///
    /// - Important:
    ///   - The same `Anchor` can be defined multiple times. Each call records another world transform. When you later
    ///     call `anchored(to:)` with that anchor, the geometry is duplicated, one instance per definition, at the
    ///     same world-space locations and orientations as captured by the anchor.
    ///   - If an anchor is referenced but has no definitions by the time the model is fully built, a warning is
    ///     printed.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located. If
    ///     no alignment is specified, the origin is used.
    ///   - offset: An optional `Vector3D` used to offset the anchor.
    ///   - direction: An optional direction vector relative to the current orientation, applied after alignment and
    ///     offset. This direction becomes the positive Z of this anchor.
    ///   - rotation: An optional rotation around the direction vector.
    /// - Returns: The geometry with a defined anchor.
    ///
    func definingAnchor(
        _ anchor: Anchor,
        at alignment: GeometryAlignment3D...,
        offset: Vector3D = .zero,
        pointing direction: Direction3D = .up,
        rotated rotation: Angle = 0°
    ) -> any Geometry3D {
        definingAnchor(
            anchor,
            alignment: alignment.merged,
            transform: .identity
                .rotated(z: rotation)
                .rotated(from: .up, to: direction)
                .translated(offset)
        )
    }
}

public extension Geometry2D {
    /// Defines an anchor point.
    ///
    /// Use this method to mark the current coordinate system as an anchor. The anchor captures the current
    /// transformation state and applies the provided transform. The resulting world transform is recorded for
    /// later use by `anchored(to:)`.
    ///
    /// - Important:
    ///   - The same `Anchor` can be defined multiple times across a geometry tree. Each definition records a separate
    ///     world transform. When you later call `anchored(to:)` with that anchor, the geometry is duplicated, one
    ///     instance per definition, at the same world-space locations and orientations as captured by the anchor.
    ///   - If an anchor is referenced but has no definitions by the time the model is fully built, a warning is
    ///     printed.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - transform: A transform applied relative to the current transformation state; the resulting world transform
    ///     is recorded as an anchor definition.
    /// - Returns: The geometry with a defined anchor.
    ///
    func definingAnchor(_ anchor: Anchor, transform: Transform2D) -> any Geometry2D {
        definingAnchor(anchor, alignment: .none, transform: transform)
    }

    /// Defines an anchor point.
    ///
    /// Use this method to mark a specific coordinate system as an anchor. The anchor captures the current
    /// transformation state, optionally applying an additional alignment, offset, and rotation. The resulting world
    /// transform is recorded for later use by `anchored(to:)`.
    ///
    /// The applied transform is constructed by:
    /// 1) applying the specified alignment (if any),
    /// 2) translating by `offset`,
    /// 3) rotating by `rotation`.
    ///
    /// - Important:
    ///   - The same `Anchor` can be defined multiple times. Each call records another world transform. When you later
    ///     call `anchored(to:)` with that anchor, the geometry is duplicated, one instance per definition, at the
    ///     same world-space locations and orientations as captured by the anchor.
    ///   - If an anchor is referenced but has no definitions by the time the model is fully built, a warning is
    ///     printed.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located. If
    ///     no alignment is specified, the origin is used.
    ///   - offset: An optional `Vector2D` used to offset the anchor.
    ///   - rotation: An optional rotation applied to the anchor.
    /// - Returns: The geometry with a defined anchor.
    ///
    func definingAnchor(
        _ anchor: Anchor,
        at alignment: GeometryAlignment2D...,
        offset: Vector2D = .zero,
        rotated rotation: Angle = 0°
    ) -> any Geometry2D {
        definingAnchor(
            anchor,
            alignment: alignment.merged,
            transform: .identity
                .rotated(rotation)
                .translated(offset)
        )
    }
}

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

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> Output.BuildResult {
        let reset = environment.transform.inverse
        let localTransforms: [Output.Transform] = environment.transforms(for: anchor).map {
            Output.Transform($0.concatenated(with: reset))
        }
        return try await context.buildResult(for: reader(localTransforms), in: environment)
            .modifyingElement(ReferenceState.self) { $0.markUsed(anchor: anchor) }
    }
}
