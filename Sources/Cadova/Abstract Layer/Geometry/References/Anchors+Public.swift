import Foundation

public struct Anchor: Hashable, Sendable, CustomStringConvertible {
    internal let id = UUID()
    internal let label: String?

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
    /// Defines an anchor point
    ///
    /// Use this method to mark the current coordinate system as an anchor. This anchor can then be used to position
    /// and orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current
    /// transformation state and applies an additional transform.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - transform: A transform applied relative to the current transformation state
    /// - Returns: The geometry with a defined anchor.
    ///
    func definingAnchor(_ anchor: Anchor, transform: Transform3D) -> any Geometry3D {
        definingAnchor(anchor, alignment: .none, transform: transform)
    }

    /// Defines an anchor point
    ///
    /// Use this method to mark a specific coordinate system as an anchor. This anchor can then be used to position and
    /// orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current
    /// transformation state, optionally applying an additional alignment, offset, direction and rotation around the
    /// direction vector.
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

    /// Aligns this 3D geometry to a previously defined anchor.
    ///
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate
    /// system. It's used to position this geometry based on the location and orientation of an anchor.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with the specified anchor.
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
