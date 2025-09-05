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

public struct Polygon: Shape2D {
    internal let pointsProvider: PolygonPoints

    internal init(provider: PolygonPoints) {
        pointsProvider = provider
    }

    /// Creates a new `Polygon` instance with the specified points.
    ///
    /// - Parameter points: An array of `Vector2D` that defines the vertices of the polygon.
    public init(_ points: [Vector2D]) {
        self.init(provider: .literal(points))
    }

    /// Creates a new `Polygon` instance with the specified 2D Bezier path.
    ///
    /// - Parameter bezierPath: A `BezierPath2D` that defines the shape of the polygon.
    public init(_ bezierPath: BezierPath2D) {
        self.init(provider: .bezierPath(bezierPath))
    }

    public init(_ polygons: [Polygon]) {
        self.init(provider: .concatenated(polygons.map(\.pointsProvider)))
    }

    public var body: any Geometry2D {
        CachedNode(name: "polygon", parameters: pointsProvider) { environment, context in
            let polygonList = SimplePolygonList([SimplePolygon(points(in: environment))])
            return .shape(.polygons(polygonList, fillRule: environment.fillRule))
        }
    }
}

public extension Polygon {
    /// Transforms the polygon using an affine transformation.
    /// - Parameter transform: An `Transform2D` to apply to the polygon.
    /// - Returns: A new `Polygon` instance with transformed vertices.
    func transformed(_ transform: Transform2D) -> Polygon {
        Polygon(provider: .transformed(pointsProvider, transform))
    }

    func appending(_ other: Polygon) -> Polygon {
        Polygon(provider: .concatenated([pointsProvider, other.pointsProvider]))
    }

    func reversed() -> Polygon {
        Polygon(provider: .reversed(pointsProvider))
    }

    static func +(_ lhs: Polygon, _ rhs: Polygon) -> Polygon {
        lhs.appending(rhs)
    }
}
