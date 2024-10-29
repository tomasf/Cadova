import Foundation

fileprivate struct Intersection<V: Vector> {
    let children: [V.Geometry]

    let moduleName = "intersection"
    let boundaryMergeStrategy = Boundary<V>.MergeStrategy.boxIntersection
    let combination = GeometryCombination.intersection
}

extension Intersection<Vector2D>: Geometry2D, CombinedGeometry2D {}
extension Intersection<Vector3D>: Geometry3D, CombinedGeometry3D {}

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
    ///   - with: The other geometry to intersect with this
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
    ///   - with: The other geometry to intersect with this
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

public func intersection(@GeometryBuilder2D with other: () -> [any Geometry2D]) -> any Geometry2D {
    Intersection(children: other())
}

public func intersection(@GeometryBuilder3D with other: () -> [any Geometry3D]) -> any Geometry3D {
    Intersection(children: other())
}
