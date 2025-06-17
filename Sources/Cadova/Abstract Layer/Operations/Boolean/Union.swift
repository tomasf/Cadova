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
/// the `.adding` method available on `Geometry` The `.adding`  method allows you to create
/// unions in a more concise and readable way by chaining it directly to an existing
/// geometry, making it the preferred approach in most cases.
///
/// ## Examples
/// ```swift
/// Union {
///     Cylinder(diameter: 4, height: 10)
///     Box([10, 10, 3])
/// }
/// ```
///
/// ### Using .adding (preferred)
/// ```swift
/// Cylinder(diameter: 4, height: 10)
///     .adding {
///         Box([10, 10, 3])
///     }
/// ```
///
/// Both examples create a union where the cylinder and box are combined into a single geometry.
///
public struct Union<D: Dimensionality>: Geometry {
    let children: @Sendable () async throws -> [D.Geometry]

    internal init(closure children: @Sendable @escaping () async throws -> [D.Geometry]) {
        self.children = children
    }

    internal init(children: [D.Geometry]) {
        self.children = { children }
    }

    // Union can't be a Shape because Shape uses a geometry builder which uses Union
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: BooleanGeometry(children: children(), type: .union), in: environment)
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
    public init(@ArrayBuilder<D.Geometry> _ body: @Sendable @escaping () -> [D.Geometry]) {
        self.init(closure: body)
    }

    public init(@ArrayBuilder<D.Geometry> _ body: @Sendable @escaping () async throws -> [D.Geometry]) async rethrows {
        self.init(closure: body)
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

public extension Geometry {
    /// Groups this geometry with additional geometry, forming a union that is treated as a single shape.
    ///
    /// This method combines the current geometry with one or more additional geometries using a union operation. The
    /// result is a composite shape where all parts are merged into one. This is especially useful when positioning or
    /// transforming a group of objects as a whole.
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .adding {
    ///         Circle(diameter: 5)
    ///         Rectangle([2, 2]).translated(x: 6)
    ///     }
    ///     .translated(x: 10)
    /// ```
    /// In this example, the circle and small rectangle are grouped with the base rectangle, and the entire group is
    /// then translated.
    ///
    /// - Parameter bodies: A closure returning one or more geometries to be combined.
    /// - Returns: A new geometry that is the union of the current geometry and the provided geometries.
    func adding(@SequenceBuilder<D> _ bodies: @escaping @Sendable () -> [D.Geometry]) -> D.Geometry {
        Union { [self] + bodies() }
    }

    /// Groups this geometry with additional geometry, forming a union that is treated as a single shape.
    ///
    /// This method combines the current geometry with one or more additional geometries using a union operation. The
    /// result is a composite shape where all parts are merged into one. This is especially useful when positioning or
    /// transforming a group of objects as a whole.
    ///
    /// This overload accepts a variadic list of optional geometries, allowing convenient conditional inclusion without
    /// needing to use builders or unwrap values manually.
    ///
    /// - Parameter bodies: A closure returning one or more geometries to be combined.
    /// - Returns: A new geometry that is the union of the current geometry and the provided geometries.
    ///
    func adding(_ bodies: D.Geometry?...) -> D.Geometry {
        Union([self] + bodies)
    }
}
