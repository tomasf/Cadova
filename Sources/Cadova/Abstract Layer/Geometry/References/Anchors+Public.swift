import Foundation

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

    /// Aligns this 3D geometry to a previously defined anchor (or anchors).
    ///
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate
    /// system. If the anchor has been defined multiple times, the geometry is duplicated and distributed to each
    /// recorded world transform, producing one instance per definition at the same world-space location and orientation
    /// as captured by the anchor.
    ///
    /// If the anchor has no definitions available by the time the model is fully built, no instances are produced and
    /// a warning is printed.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with all definitions of the specified anchor.
    ///
    func anchored(to anchor: Anchor) -> any Geometry3D {
        readEnvironment { environment in
            modifyingResult(ReferenceState.self) { body, anchorState in
                let reset = environment.transform.inverse
                let globalTransforms = anchorState.read(anchor: anchor)
                    .union(environment.transforms(for: anchor))
                let localTransforms = globalTransforms.map { $0.concatenated(with: reset) }

                body.distributed(at: localTransforms)
            }
        }
    }
}
