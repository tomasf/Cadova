import Foundation

/// A geometry type that represents the union (combined area or volume) of multiple shapes.
///
/// `Union` groups multiple 2D or 3D shapes and treats them as a single geometry, forming
/// a combined area or volume encompassing all input geometries. This is useful for creating
/// complex shapes by merging simpler components.
///
/// ## Note
/// While you can use `Union` directly, it is generally more convenient to use
/// the `.adding` method available on `Geometry2D` and `Geometry3D`. The `.adding`
/// method allows you to create unions in a more concise and readable way by chaining
/// it directly to an existing geometry, making it the preferred approach in most cases.
///
/// ## Examples
/// ### 2D Union
/// ```swift
/// Union {
///     Circle(diameter: 4)
///     Rectangle([10, 10])
/// }
/// ```
///
/// ### Using .adding (Preferred)
/// ```swift
/// Circle(diameter: 4)
///     .adding {
///         Rectangle([10, 10])
///     }
/// ```
///
/// ### 3D Union
/// ```swift
/// Union {
///     Cylinder(diameter: 4, height: 10)
///     Box([10, 10, 3])
/// }
/// ```
///
/// ### Using .adding (Preferred)
/// ```swift
/// Cylinder(diameter: 4, height: 10)
///     .adding {
///         Box([10, 10, 3])
///     }
/// ```
///
/// This will create a union where the cylinder and box are combined into a single geometry.
/// 
public struct Union<V: Vector> {
    let children: [V.Geometry]
    let moduleName = "union"
    let boundaryMergeStrategy = Boundary<V>.MergeStrategy.union
    let combination = GeometryCombination.union

    internal init(children: [V.Geometry]) {
        self.children = children
    }
}

extension Union<Vector2D>: Geometry2D, CombinedGeometry2D {
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
    public init(@GeometryBuilder2D _ body: () -> [any Geometry2D]) {
        self.init(children: body())
    }

    /// Form a union to group multiple pieces of geometry together and treat them as one
    ///
    /// ## Example
    /// ```swift
    /// Union([Circle(diameter: 4), Rectangle([10, 10]))
    ///     .translate(x: 10)
    /// ```
    public init(_ children: [(any Geometry2D)?]) {
        self.init(children: children.compactMap { $0 })
    }
}

extension Union<Vector3D>: Geometry3D, CombinedGeometry3D {
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
    public init(@GeometryBuilder3D _ body: () -> [any Geometry3D]) {
        self.init(children: body())
    }

    /// Form a union to group multiple pieces of geometry together and treat them as one
    ///
    /// ## Example
    /// ```swift
    /// Union([Cylinder(diameter: 4, height: 10), Box([10, 10, 3]))
    ///     .translate(x: 10)
    /// ```
    public init(_ children: [(any Geometry3D)?]) {
        self.init(children: children.compactMap { $0 })
    }
}
