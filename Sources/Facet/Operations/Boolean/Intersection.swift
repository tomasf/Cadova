import Foundation

/// A geometry type that represents the intersection (common overlap) of multiple shapes.
///
/// `Intersection` is a combined geometry type that takes multiple 2D or 3D shapes
/// and returns their intersection – the area or volume where all shapes overlap.
///
/// The resulting intersection is defined based on the specific geometries provided
/// and can be useful for creating complex shapes from overlapping regions of simpler shapes.
///
/// ## Note
/// While you can use `Intersection` directly, it is generally more convenient to use
/// the `.intersecting` method available on `Geometry2D` and `Geometry3D`. The `.intersecting`
/// method allows you to create intersections in a more concise and readable way by chaining
/// it directly to an existing geometry, making it the preferred approach in most cases.
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
public struct Intersection<V: Vector> {
    internal let children: [V.Geometry]

    internal let moduleName = "intersection"
    internal let boundaryMergeStrategy = Boundary<V>.MergeStrategy.boxIntersection
    internal let combination = GeometryCombination.intersection
}

extension Intersection<Vector2D>: Geometry2D, CombinedGeometry2D {
    /// Creates a 2D intersection of multiple geometries.
    ///
    /// This initializer takes a closure that provides an array of 2D geometries to intersect.
    ///
    /// - Parameter children: A closure providing the geometries to be intersected.
    public init(@GeometryBuilder2D _ children: () -> [any Geometry2D]) {
        self.init(children: children())
    }
}

extension Intersection<Vector3D>: Geometry3D, CombinedGeometry3D {
    /// Creates a 3D intersection of multiple geometries.
    ///
    /// This initializer takes a closure that provides an array of 3D geometries to intersect.
    ///
    /// - Parameter children: A closure providing the geometries to be intersected.
    public init(@GeometryBuilder3D _ children: () -> [any Geometry3D]) {
        self.init(children: children())
    }
}

public extension Geometry2D {
    /// Intersect this geometry with other geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .intersecting {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - other: The other geometry to intersect with this
    /// - Returns: The intersection (overlap) of this geometry and the input

    func intersecting(@GeometryBuilder2D _ other: () -> [any Geometry2D]) -> any Geometry2D {
        Intersection(children: [self] + other())
    }

    func intersecting(_ other: any Geometry2D...) -> any Geometry2D {
        Intersection(children: [self] + other)
    }
}

public extension Geometry3D {
    /// Intersect this geometry with other geometry
    ///
    /// ## Example
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

    func intersecting(@GeometryBuilder3D _ other: () -> [any Geometry3D]) -> any Geometry3D {
        Intersection(children: [self] + other())
    }

    func intersecting(_ other: any Geometry3D...) -> any Geometry3D {
        Intersection(children: [self] + other)
    }
}

public extension Sequence {
    func mapIntersection(@GeometryBuilder3D _ transform: (Element) throws -> any Geometry3D) rethrows -> any Geometry3D {
        Intersection(children: try map(transform))
    }
    
    func mapIntersection(@GeometryBuilder2D _ transform: (Element) throws -> any Geometry2D) rethrows -> any Geometry2D {
        Intersection(children: try map(transform))
    }
}
