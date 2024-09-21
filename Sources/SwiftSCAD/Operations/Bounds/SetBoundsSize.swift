import Foundation

public extension Geometry2D {
    private func settingBounds(snapshot: GeometrySnapshot2D, currentSize: Vector2D, targetSize: Vector2D, alignment: GeometryAlignment2D) -> any Geometry2D {
        let translation = (targetSize - currentSize) * alignment.factors
        return snapshot
            .aligned(at: .origin)
            .translated(translation)
            .settingBounds(.init(minimum: .zero, maximum: targetSize))
    }

    /// Set the size of the bounding box of this geometry.
    ///
    /// The resulting bounding box is aligned at the origin, with a size specified by the given parameters. If a dimension is not provided, the current size for that dimension is preserved.
    /// The geometry is translated within the new bounding box according to the specified alignment.
    /// - Parameters:
    ///   - x: The new X size for the bounding box. If `nil`, the current X size is preserved.
    ///   - y: The new Y size for the bounding box. If `nil`, the current Y size is preserved.
    ///   - alignment: The alignment specification that controls how the geometry is positioned within the new bounding box.
    /// - Returns: A modified geometry with the updated bounding box.

    func settingBoundsSize(x: Double? = nil, y: Double? = nil, alignment: GeometryAlignment2D...) -> any Geometry2D {
        measuringBounds { snapshot, box in
            let newSize = Vector2D(x ?? box.size.x, y ?? box.size.y)
            settingBounds(snapshot: snapshot, currentSize: box.size, targetSize: newSize, alignment: alignment.merged)
        }
    }

    /// Set the size of the bounding box of this geometry.
    ///
    /// The resulting bounding box is aligned at the origin with the specified size. The geometry is translated within the new bounding box according to the specified alignment.
    /// - Parameters:
    ///   - targetSize: The new size of the bounding box.
    ///   - alignment: The alignment specification that controls how the geometry is positioned within the new bounding box.
    /// - Returns: A modified geometry with the updated bounding box.

    func settingBoundsSize(_ targetSize: Vector2D, alignment: GeometryAlignment2D...) -> any Geometry2D {
        measuringBounds { snapshot, box in
            settingBounds(snapshot: snapshot, currentSize: box.size, targetSize: targetSize, alignment: alignment.merged)
        }
    }
}

public extension Geometry3D {
    private func settingBounds(snapshot: GeometrySnapshot3D, currentSize: Vector3D, targetSize: Vector3D, alignment: GeometryAlignment3D) -> any Geometry3D {
        let translation = (targetSize - currentSize) * alignment.factors
        return snapshot
            .aligned(at: .origin)
            .translated(translation)
            .settingBounds(.init(minimum: .zero, maximum: targetSize))
    }

    /// Set the size of the bounding box of this geometry.
    ///
    /// The resulting bounding box is aligned at the origin, with a size specified by the given parameters. If a dimension is not provided, the current size for that dimension is preserved.
    /// The geometry is translated within the new bounding box according to the specified alignment.
    /// - Parameters:
    ///   - x: The new X size for the bounding box. If `nil`, the current X size is preserved.
    ///   - y: The new Y size for the bounding box. If `nil`, the current Y size is preserved.
    ///   - z: The new Z size for the bounding box. If `nil`, the current Z size is preserved.
    ///   - alignment: The alignment specification that controls how the geometry is positioned within the new bounding box.
    /// - Returns: A modified geometry with the updated bounding box.

    func settingBoundsSize(x: Double? = nil, y: Double? = nil, z: Double? = nil, alignment: GeometryAlignment3D...) -> any Geometry3D {
        measuringBounds { snapshot, box in
            let newSize = Vector3D(x ?? box.size.x, y ?? box.size.y, z ?? box.size.z)
            settingBounds(snapshot: snapshot, currentSize: box.size, targetSize: newSize, alignment: alignment.merged)
        }
    }

    /// Set the size of the bounding box of this geometry.
    ///
    /// The resulting bounding box is aligned at the origin with the specified size. The geometry is translated within the new bounding box according to the specified alignment.
    /// - Parameters:
    ///   - targetSize: The new size of the bounding box.
    ///   - alignment: The alignment specification that controls how the geometry is positioned within the new bounding box.
    /// - Returns: A modified geometry with the updated bounding box.

    func settingBoundsSize(_ targetSize: Vector3D, alignment: GeometryAlignment3D...) -> any Geometry3D {
        measuringBounds { snapshot, box in
            settingBounds(snapshot: snapshot, currentSize: box.size, targetSize: targetSize, alignment: alignment.merged)
        }
    }
}
