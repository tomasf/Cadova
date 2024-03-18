import Foundation

public extension Geometry2D {
    /// Defines an anchor point on this geometry.
    ///
    /// Use this method to mark a specific point on a geometry as an anchor. This anchor can then be used to position this geometry relative to others by aligning the anchor point to a specified location. The anchor captures the current transformation state, allowing precise control over the geometry's placement.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located.
    ///   - offset: An optional `Vector2D` used to offset the anchor from the specified alignment position.
    /// - Returns: A modified version of the geometry with the defined anchor.
    func definingAnchor(_ anchor: Anchor, at alignment: GeometryAlignment2D..., offset: Vector2D = .zero) -> any Geometry2D {
        DefineAnchor2D(body: self, anchor: anchor, alignment: .init(merging: alignment), offset: offset)
    }

    /// Aligns this geometry to a previously defined anchor.
    ///
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate system. It's used to position this geometry based on the location and orientation of an anchor defined elsewhere.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with the specified anchor.
    func anchored(to anchor: Anchor) -> any Geometry2D {
        ApplyAnchor2D(body: self, anchor: anchor)
    }
}

public extension Geometry3D {
    /// Defines an anchor point on this 3D geometry.
    ///
    /// Use this method to mark a specific point on a geometry as an anchor. This anchor can then be used to position this geometry relative to others by aligning the anchor point to a specified location. The anchor captures the current transformation state, allowing precise control over the geometry's placement.
    ///
    /// - Parameters:
    ///   - anchor: The `Anchor` to define on this geometry.
    ///   - alignment: One or more alignment options specifying where on the geometry the anchor should be located.
    ///   - offset: An optional `Vector3D` used to offset the anchor from the specified alignment position.
    /// - Returns: A modified version of the geometry with the defined anchor.
    func definingAnchor(_ anchor: Anchor, at alignment: GeometryAlignment3D..., offset: Vector3D = .zero) -> any Geometry3D {
        DefineAnchor3D(body: self, anchor: anchor, alignment: .init(merging: alignment), offset: offset)
    }

    /// Aligns this 3D geometry to a previously defined anchor.
    ///
    /// This method transforms the geometry so that the specified anchor point aligns with the origin of the coordinate system. It's used to position this geometry based on the location and orientation of an anchor defined elsewhere.
    ///
    /// - Parameter anchor: The `Anchor` to which this geometry should be aligned.
    /// - Returns: A modified version of the geometry, transformed to align with the specified anchor.
    func anchored(to anchor: Anchor) -> any Geometry3D {
        ApplyAnchor3D(body: self, anchor: anchor)
    }
}

public extension Anchor {
    /// Defines a 2D anchor with a placeholder geometry.
    ///
    /// This method creates a placeholder 2D geometry to define the anchor. The placeholder is immaterial, serving solely to establish the anchor's position and orientation in 2D space. It's particularly useful when you need to define an anchor independent of existing geometries, allowing for custom transformations.
    ///
    /// - Returns: A placeholder `Geometry2D` instance associated with this anchor, which is disabled and does not contribute to the final geometry.
    func define() -> any Geometry2D {
        DefineAnchor2D(body: Rectangle(0).disabled(), anchor: self, alignment: .none, offset: .zero)
    }

    /// Defines a 3D anchor with a placeholder geometry.
    ///
    /// This method creates a placeholder 3D geometry to define the anchor. The placeholder is immaterial, serving solely to establish the anchor's position and orientation in 3D space. It's particularly useful when you need to define an anchor independent of existing geometries, allowing for custom transformations.
    ///
    /// - Returns: A placeholder `Geometry3D` instance associated with this anchor, which is disabled and does not contribute to the final geometry.
    func define() -> any Geometry3D {
        DefineAnchor3D(body: Box(0).disabled(), anchor: self, alignment: .none, offset: .zero)
    }
}
