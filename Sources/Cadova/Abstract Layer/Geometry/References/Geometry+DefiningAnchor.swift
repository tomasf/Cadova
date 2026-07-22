import Foundation

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
