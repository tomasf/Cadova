import Foundation

fileprivate struct MinkowskiSum<V: Vector> {
    let children: [V.Geometry]
    let moduleName = "minkowski"
    let boundaryMergeStrategy = Boundary<V>.MergeStrategy.minkowskiSum
    let combination = GeometryCombination.minkowskiSum
    let needsColorDeclaration = true
}

extension MinkowskiSum<Vector2D>: Geometry2D, CombinedGeometry2D {}
extension MinkowskiSum<Vector3D>: Geometry3D, CombinedGeometry3D {
    var supportsPreviewConvexity: Bool { true }
}


public extension Geometry2D {
    /// Combines the current geometry with one or more other geometries using the Minkowski sum operation.
    ///
    /// The Minkowski sum operation creates a new geometry that represents the combination of this geometry with each of the geometries provided by the `adding` closure. This operation is akin to blending the spatial features of the geometries, where the resulting shape embodies the outline that would be traced by moving one shape around the perimeter of the other.
    ///
    /// - Parameter other: The 3D geometries to combine with this geometry.
    /// - Returns: A geometry representing the Minkowski sum
    func minkowskiSum(@GeometryBuilder2D adding other: () -> [any Geometry2D]) -> any Geometry2D {
        MinkowskiSum(children: [self] + other())
    }
}

public extension Geometry3D {
    /// Combines the current geometry with one or more other geometries using the Minkowski sum operation.
    ///
    /// The Minkowski sum operation creates a new geometry that represents the combination of this geometry with each of the geometries provided by the `adding` closure. This operation is akin to blending the spatial features of the geometries, where the resulting shape embodies the outline that would be traced by moving one shape around the perimeter of the other.
    ///
    /// - Parameter other: The 3D geometries to combine with this geometry.
    /// - Returns: A geometry representing the Minkowski sum
    func minkowskiSum(@GeometryBuilder3D adding other: () -> [any Geometry3D]) -> any Geometry3D {
        MinkowskiSum(children: [self] + other())
    }
}
