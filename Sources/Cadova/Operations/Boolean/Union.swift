import Foundation
import Manifold3D

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
public struct Union<D: Dimensionality>: CompositeGeometry {
    let children: [D.Geometry]

    internal init(children: [D.Geometry]) {
        self.children = children
    }

    public var body: D.Geometry {
        BooleanGeometry(children: children, type: .union)
    }
}

extension Union {
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
    public init(@ArrayBuilder<D.Geometry> _ body: () -> [D.Geometry]) {
        self.init(children: body())
    }

    public init(@ArrayBuilder<D.Geometry> _ body: () async -> [D.Geometry]) async {
        self.init(children: await body())
    }

    /// Form a union to group multiple pieces of geometry together and treat them as one
    ///
    /// ## Example
    /// ```swift
    /// Union([Circle(diameter: 4), Rectangle([10, 10]))
    ///     .translate(x: 10)
    /// ```
    public init<S: Sequence<D.Geometry?>>(_ children: S) {
        self.init(children: children.compactMap { $0 })
    }
}

public extension Collection {
    func mapUnion<D: Dimensionality>(
        @GeometryBuilder<D> _ transform: (Element) throws -> D.Geometry
    ) rethrows -> D.Geometry {
        Union(children: try map(transform))
    }
}

public extension Collection where Element: Sendable {
    func mapUnion<D: Dimensionality>(
        @GeometryBuilder<D> _ transform: @Sendable @escaping (Element) async -> D.Geometry
    ) async -> D.Geometry {
        Union(children: await asyncMap(transform))
    }

}
