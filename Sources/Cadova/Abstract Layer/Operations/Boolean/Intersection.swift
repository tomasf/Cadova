import Foundation
import Manifold3D

/// A geometry type that represents the intersection (common overlap) of multiple shapes.
///
/// `Intersection` is a combined geometry type that takes multiple 2D or 3D shapes and returns their intersection –
/// the area or volume where all shapes overlap. The resulting intersection is defined based on the specific geometries
/// provided and can be useful for creating complex shapes from overlapping regions of simpler shapes.
///
/// ## Note
/// While you can use `Intersection` directly, it is generally more convenient to use the `.intersecting` method
/// available on `Geometry2D` and `Geometry3D`. The `.intersecting` method allows you to create intersections in a more
/// concise and readable way by chaining it directly to an existing geometry, making it the preferred approach in
/// most cases.
///
/// ## Examples
/// ### 2D Intersection
/// ```swift
/// Intersection {
///     Rectangle([10, 10])
///     Circle(diameter: 4)
/// }
/// ```
///
/// ### 3D Intersection
/// ```swift
/// Intersection {
///     Box([10, 10, 5])
///     Cylinder(diameter: 4, height: 3)
/// }
/// ```
///
/// This will create an intersection where the box and cylinder overlap.
///
public struct Intersection<D: Dimensionality>: Shape {
    internal let children: @Sendable () -> [D.Geometry]

    internal init(children: @Sendable @escaping () -> [D.Geometry]) {
        self.children = children
    }

    public var body: D.Geometry {
        BooleanGeometry(children: children(), type: .intersection)
    }

    /// Creates a intersection of multiple geometries.
    ///
    /// This initializer takes a closure that provides an array of geometries to intersect.
    ///
    /// - Parameter children: A closure providing the geometries to be intersected.
    public init(@ArrayBuilder<D.Geometry> _ children: @Sendable @escaping () -> [D.Geometry]) {
        self.init(children: children)
    }
}

public extension Geometry {
    /// Intersect this geometry with other geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .intersecting {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    /// ```swift
    /// Box([10, 10, 5])
    ///     .intersecting {
    ///        Cylinder(diameter: 4, height: 3)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - other: The other geometry to intersect with this
    /// - Returns: The intersection (overlap) of this geometry and the input

    func intersecting(@ArrayBuilder<D.Geometry> _ other: @Sendable @escaping () -> [D.Geometry]) -> D.Geometry {
        Intersection(children: { [self] + other() })
    }

    func intersecting(_ other: D.Geometry...) -> D.Geometry {
        Intersection(children: { [self] + other })
    }
}
