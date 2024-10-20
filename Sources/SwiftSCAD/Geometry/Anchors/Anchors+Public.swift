import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

public extension Geometry2D {
    /// Defines an anchor point on this geometry.
    ///
    /// Use this method to mark the current coordinate system as an anchor. This anchor can then be used to position and orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current transformation state and applies an additional transform.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - transform: A transform applied relative to the current transformation state
    /// - Returns: A modified version of the geometry with the defined anchor.
    func definingAnchor(_ anchor: Anchor, transform: AffineTransform2D) -> any Geometry2D {
        definingAnchor(anchor, alignment: .none, transform: transform)
    }

    /// Defines an anchor point on this geometry.
    ///
    /// Use this method to mark a specific coordinate system as an anchor. This anchor can then be used to position and orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current transformation state, optionally applying an additional alignment, offset and rotation.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located. If no alignment is specified, the origin is used.
    ///   - offset: An optional `Vector2D` used to offset the anchor from the specified alignment position.
    ///   - rotated: An optional rotation at the specified point
    /// - Returns: A modified version of the geometry with the defined anchor.
    func definingAnchor(
        _ anchor: Anchor,
        at alignment: GeometryAlignment2D...,
        offset: Vector2D = .zero,
        rotated rotation: Angle = .zero
    ) -> any Geometry2D {
        definingAnchor(anchor, alignment: alignment.merged, transform: .identity.translated(offset).rotated(rotation))
    }

    /// Aligns this geometry to a previously defined anchor.
    ///
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate system. It's used to position this geometry based on the location and orientation of an anchor defined inside this geometry.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with the specified anchor.
    func anchored(to anchor: Anchor) -> any Geometry2D {
        readEnvironment { environment in
            readingResult(AnchorList.self) { body, anchorList in
                if let transform = anchorList?.anchors[anchor] {
                    self.transformed(.init(AffineTransform3D.identity
                        .concatenated(with: environment.transform)
                        .concatenated(with: transform)
                    ))
                } else {
                    preconditionFailure("Anchor \(anchor) not found. Did you define it somewhere inside this geometry using defineAnchor(...)?")
                }
            }
        }
    }
}

public extension Geometry3D {
    /// Defines an anchor point
    ///
    /// Use this method to mark the current coordinate system as an anchor. This anchor can then be used to position and orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current transformation state and applies an additional transform.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - transform: A transform applied relative to the current transformation state
    /// - Returns: The geometry with a defined anchor.
    func definingAnchor(_ anchor: Anchor, transform: AffineTransform3D) -> any Geometry3D {
        definingAnchor(anchor, alignment: .none, transform: transform)
    }

    /// Defines an anchor point
    ///
    /// Use this method to mark a specific coordinate system as an anchor. This anchor can then be used to position and orient the geometry tree by aligning the saved transform to the origin. The anchor captures the current transformation state, optionally applying an additional alignment, offset, direction and rotation.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located. If no alignment is specified, the origin is used.
    ///   - offset: An optional `Vector3D` used to offset the anchor.
    ///   - pointing: An optional direction vector relative to the current orientation, applied after alignment and offset. This direction becomes the positive Z of this anchor.
    ///   - rotated: An optional rotation around the direction vector.
    /// - Returns: The geometry with a defined anchor.
    func definingAnchor(
        _ anchor: Anchor,
        at alignment: GeometryAlignment3D...,
        offset: Vector3D = .zero,
        pointing direction: Vector3D = .up,
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
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate system. It's used to position this geometry based on the location and orientation of an anchor defined inside this geometry.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with the specified anchor.
    func anchored(to anchor: Anchor) -> any Geometry3D {
        readEnvironment { environment in
            readingResult(AnchorList.self) { body, anchorList in
                if let transform = anchorList?.anchors[anchor] {
                    self.transformed(AffineTransform3D.identity
                        .concatenated(with: environment.transform)
                        .concatenated(with: transform)
                    )
                } else {
                    preconditionFailure("Anchor \(anchor) not found. Did you define it somewhere inside this geometry using defineAnchor(...)?")
                }
            }
        }
    }
}
