import Foundation

public extension Geometry3D {
    /// Skews the geometry by repositioning one or more corners of its bounding box.
    ///
    /// This method lets you move specific corners of the geometry’s bounding box to new **absolute positions**.
    /// The geometry is then smoothly warped to match the new shape defined by those corners,
    /// using trilinear interpolation.
    ///
    /// This works with *any 3D geometry*, not just boxes. The term "corner" refers to the corners of its
    /// bounding box. Only the corners you specify are moved. All others remain fixed.
    ///
    /// - Parameter positions: A dictionary mapping bounding box corners to new absolute positions.
    /// - Returns: A new, skewed geometry.
    ///
    /// ```swift
    /// Cylinder(diameter: 10, height: 5)
    ///     .skewingCorners([
    ///         .minXminYminZ: Vector3D(-3, 2, -4),
    ///         .minXmaxYmaxZ: Vector3D(0, 11, 6)
    ///     ])
    /// ```
    ///
    /// In this example, two corners of the cylinder’s bounding box are moved to new positions,
    /// and the cylinder is warped to match. The result is a deformed cylinder.
    ///
    func skewingCorners(_ positions: [Box.Corner: Vector3D]) -> any Geometry3D {
        measuringBounds { _, bounds in
            let fromCorners = bounds.corners
            let toCorners = fromCorners.merging(positions) { $1 }
            skewingCorners(from: fromCorners.cornerList, to: toCorners.cornerList)
        }
    }

    /// Skews the geometry by offsetting one or more corners of its bounding box by a relative amount.
    ///
    /// This works just like `skewingCorners(_:)`, but instead of providing absolute target positions,
    /// you specify **relative offsets** to apply to each corner. This is useful when deforming a
    /// shape by an amount, rather than toward a fixed position.
    ///
    /// - Parameter positions: A dictionary mapping corners to relative translation vectors.
    /// - Returns: A new, skewed geometry.
    ///
    func skewingCorners(relative positions: [Box.Corner: Vector3D]) -> any Geometry3D {
        measuringBounds { _, bounds in
            let fromCorners = bounds.corners
            let toCorners = fromCorners.merging(positions) { $0 + $1 }
            skewingCorners(from: fromCorners.cornerList, to: toCorners.cornerList)
        }
    }
}

internal extension Geometry3D {
    func skewingCorners(from source: [Vector3D], to destination: [Vector3D]) -> any Geometry3D {
        assert(source.count == 8 && destination.count == 8)

        let min = Vector3D(source.map(\.x).min()!, source.map(\.y).min()!, source.map(\.z).min()!)
        let max = Vector3D(source.map(\.x).max()!, source.map(\.y).max()!, source.map(\.z).max()!)
        let delta = max - min
        guard delta.x > 1e-8, delta.y > 1e-8, delta.z > 1e-8 else { return self }

        return warped(operationName: "skewCorners", cacheParameters: source, destination) { point in
            let t = (point - min) / delta
            let c000 = lerp(destination[0], destination[1], t: t.x)
            let c001 = lerp(destination[3], destination[2], t: t.x)
            let c010 = lerp(destination[4], destination[5], t: t.x)
            let c011 = lerp(destination[7], destination[6], t: t.x)
            let c00 = lerp(c000, c001, t: t.y)
            let c01 = lerp(c010, c011, t: t.y)
            return lerp(c00, c01, t: t.z)
        }
    }
}

internal extension BoundingBox3D {
    var corners: [Box.Corner: Vector3D] {
        .init(keys: combinations(LinearDirection.allCases, LinearDirection.allCases, LinearDirection.allCases).map(OrthogonalCorner.init)) {
            Vector3D(self[.x, $0.x], self[.y, $0.y], self[.z, $0.z])
        }
    }
}

internal extension [Box.Corner: Vector3D] {
    var cornerList: [Vector3D] {[
        self[.minXminYminZ]!, self[.maxXminYminZ]!, self[.maxXmaxYminZ]!, self[.minXmaxYminZ]!,
        self[.minXminYmaxZ]!, self[.maxXminYmaxZ]!, self[.maxXmaxYmaxZ]!, self[.minXmaxYmaxZ]!
    ]}
}
