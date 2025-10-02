import Foundation
import Manifold3D

/// Represents a two-dimensional shape defined by a series of connected points.
/// It supports initialization from an array of ``Vector2D`` points or a two-dimensional ``ParametricCurve``.
///
/// - Example:
///   - Creating a Polygon from points:
///     ```
///     let polygonFromPoints = Polygon([Vector2D(x: 0, y: 0), Vector2D(x: 10, y: 0), Vector2D(x: 5, y: 10)])
///     ```
///   - Creating a Polygon from a curve:
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

    /// Creates a new `Polygon` instance with the specified parametric curve.
    ///
    /// - Parameter curve: A `ParametricCurve<Vector2D>` that defines the shape of the polygon.
    public init<Curve: ParametricCurve<Vector2D>>(_ curve: Curve) {
        self.init(provider: .curve(.init(curve)))
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

public extension Polygon {
    /// Creates a right triangle `Polygon` with its right angle at the origin and legs aligned to the axes.
    ///
    /// - Parameters:
    ///   - x: The length of the horizontal leg along the x-axis. Positive values extend in the +x direction; negative values extend in the −x direction.
    ///   - y: The length of the vertical leg along the y-axis. Positive values extend in the +y direction; negative values extend in the −y direction.
    /// - Returns: A `Polygon` representing the specified right triangle.
    /// 
    static func rightTriangle(x: Double, y: Double) -> Self {
        Self([.zero, [x, 0], [0, y]])
    }
}
