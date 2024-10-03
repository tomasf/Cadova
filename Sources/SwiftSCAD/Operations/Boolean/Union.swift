import Foundation

fileprivate struct Union2D: CombinedGeometry2D {
    let children: [any Geometry2D]
    let moduleName = "union"
    let boundaryMergeStrategy = Boundary2D.MergeStrategy.union
    let combination = GeometryCombination.union
}

fileprivate struct Union3D: CombinedGeometry3D {
    let children: [any Geometry3D]
    let moduleName = "union"
    let boundaryMergeStrategy = Boundary3D.MergeStrategy.union
    let combination = GeometryCombination.union
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union {
///     Circle(diameter: 4)
///     Rectangle([10, 10])
/// }
/// .translate(x: 10)
/// ```
public func Union(@UnionBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
    body()
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union([Circle(diameter: 4), Rectangle([10, 10]))
///     .translate(x: 10)
/// ```
public func Union(_ children: [(any Geometry2D)?]) -> any Geometry2D {
    let finalChildren = children.compactMap { $0 }
    if finalChildren.count == 1 {
        return finalChildren[0]
    } else {
        return Union2D(children: finalChildren)
    }
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union {
///     Cylinder(diameter: 4, height: 10)
///     Box([10, 10, 3])
/// }
/// .translate(x: 10)
/// ```
public func Union(@UnionBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
    body()
}

/// Form a union to group multiple pieces of geometry together and treat them as one
///
/// ## Example
/// ```swift
/// Union([Cylinder(diameter: 4, height: 10), Box([10, 10, 3]))
///     .translate(x: 10)
/// ```
public func Union(_ children: [(any Geometry3D)?]) -> any Geometry3D {
    let finalChildren = children.compactMap { $0 }
    if finalChildren.count == 1 {
        return finalChildren[0]
    } else {
        return Union3D(children: finalChildren)
    }
}
