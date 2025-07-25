import Foundation
import Manifold3D

/// Represents a two-dimensional shape defined by a series of connected points.
/// It supports initialization from an array of ``Vector2D`` points or a two-dimensional ``BezierPath``.
///
/// - Example:
///   - Creating a Polygon from points:
///     ```
///     let polygonFromPoints = Polygon([Vector2D(x: 0, y: 0), Vector2D(x: 10, y: 0), Vector2D(x: 5, y: 10)])
///     ```
///   - Creating a Polygon from a Bezier path:
///     ```
///     let bezierPath = BezierPath2D(startPoint: .zero)
///                      .addingCubicCurve(controlPoint1: [10, 65], controlPoint2: [55, -20], end: [60, 40])
///     let polygonFromBezierPath = Polygon(bezierPath)
///     ```

public struct Polygon: Shape {
    public typealias D = D2
    internal let pointsProvider: any PolygonPointsProvider

    internal init(provider: any PolygonPointsProvider) {
        pointsProvider = provider
    }

    /// Creates a new `Polygon` instance with the specified points.
    ///
    /// - Parameter points: An array of `Vector2D` that defines the vertices of the polygon.
    public init(_ points: [Vector2D]) {
        self.init(provider: points)
    }

    /// Creates a new `Polygon` instance with the specified 2D Bezier path.
    ///
    /// - Parameter bezierPath: A `BezierPath2D` that defines the shape of the polygon.
    public init(_ bezierPath: BezierPath2D) {
        self.init(provider: bezierPath)
    }

    public init(_ polygons: [Polygon]) {
        self.init(provider: JoinedPolygonPoints(providers: polygons.map(\.pointsProvider)))
    }

    public var body: any Geometry2D {
        @Environment var environment

        let polygonList = SimplePolygonList([SimplePolygon(points(in: environment))])
        return NodeBasedGeometry(.shape(.polygons(polygonList, fillRule: environment.fillRule)))
    }
}

public extension Polygon {
    /// Applies a transformation function to each vertex of the polygon.
    /// - Parameter transformation: A closure that takes a `Vector2D` and returns a transformed `Vector2D`.
    /// - Returns: A new `Polygon` instance with transformed vertices.
    func applying(_ transformation: @Sendable @escaping (Vector2D) -> Vector2D) -> Polygon {
        Polygon(provider: TransformedPolygonPoints(innerProvider: pointsProvider, transformation: transformation))
    }

    /// Transforms the polygon using an affine transformation.
    /// - Parameter transform: An `Transform2D` to apply to the polygon.
    /// - Returns: A new `Polygon` instance with transformed vertices.
    func transformed(_ transform: Transform2D) -> Polygon {
        applying { transform.apply(to: $0) }
    }

    func appending(_ other: Polygon) -> Polygon {
        .init(provider: JoinedPolygonPoints(providers: [pointsProvider, other.pointsProvider]))
    }

    func reversed() -> Polygon {
        .init(provider: ReversedPolygonPoints(innerProvider: pointsProvider))
    }

    static func +(_ lhs: Polygon, _ rhs: Polygon) -> Polygon {
        lhs.appending(rhs)
    }
}
