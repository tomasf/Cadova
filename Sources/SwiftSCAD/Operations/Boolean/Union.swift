import Foundation

// Remove underscore when deprecated Union global func is removed
fileprivate struct _Union<V: Vector> {
    let children: [V.Geometry]
    let moduleName = "union"
    let boundaryMergeStrategy = Boundary<V>.MergeStrategy.union
    let combination = GeometryCombination.union
}

extension _Union<Vector2D>: Geometry2D, CombinedGeometry2D {}
extension _Union<Vector3D>: Geometry3D, CombinedGeometry3D {}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// union {
///     Circle(diameter: 4)
///     Rectangle([10, 10])
/// }
/// .translate(x: 10)
/// ```
public func union(@GeometryBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
    body()
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// union([Circle(diameter: 4), Rectangle([10, 10]))
///     .translate(x: 10)
/// ```
public func union(_ children: [(any Geometry2D)?]) -> any Geometry2D {
    let finalChildren = children.compactMap { $0 }
    if finalChildren.count == 1 {
        return finalChildren[0]
    } else {
        return _Union(children: finalChildren)
    }
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// union {
///     Cylinder(diameter: 4, height: 10)
///     Box([10, 10, 3])
/// }
/// .translate(x: 10)
/// ```
public func union(@GeometryBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
    body()
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// union([Cylinder(diameter: 4, height: 10), Box([10, 10, 3]))
///     .translate(x: 10)
/// ```
public func union(_ children: [(any Geometry3D)?]) -> any Geometry3D {
    let finalChildren = children.compactMap { $0 }
    if finalChildren.count == 1 {
        return finalChildren[0]
    } else {
        return _Union(children: finalChildren)
    }
}
