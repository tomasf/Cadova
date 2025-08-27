import Foundation

public extension Polygon {
    /// A structure containing geometric metrics for a polygon.
    ///
    /// `Metrics` provides useful properties derived from the polygon's shape,
    /// such as its point list, bounding box, total edge length, and enclosed area.
    /// This information is often used for inspection, analysis, or further geometric computation.
    ///
    /// - SeeAlso: ``Polygon/readMetrics(_:)``
    ///
    struct Metrics {
        private let polygon: SimplePolygon

        /// The list of 2D points defining the polygon’s perimeter, in order.
        public var points: [Vector2D] { polygon.vertices }

        /// The axis-aligned bounding box that tightly contains the polygon.
        public var boundingBox: BoundingBox2D { polygon.boundingBox }

        /// The total length of all edges of the polygon.
        public var length: Double { polygon.length }

        /// The signed area enclosed by the polygon.
        /// This value is always non-negative.
        public var area: Double { polygon.area }

        internal init(polygon: Polygon, environment: EnvironmentValues) {
            self.polygon = SimplePolygon(polygon.points(in: environment))
        }
    }
}

public extension Polygon {
    /// Returns the points defining the polygon within a given environment.
    /// - Parameter environment: The environment context.
    /// - Returns: An array of `Vector2D` representing the polygon's vertices.
    func points(in environment: EnvironmentValues) -> [Vector2D] {
        pointsProvider.points(in: environment)
    }

    /// Reads and provides metrics (points, bounding box, length, area) for the polygon and allows
    /// further geometry processing in a 2D environment.
    /// - Parameter reader: A closure receiving `Metrics` of the polygon and returning a 2D geometry.
    /// - Returns: A 2D geometry result from the reader closure.
    func readMetrics<D: Dimensionality>(@GeometryBuilder<D> _ reader: @Sendable @escaping (Metrics) -> D.Geometry) -> D.Geometry {
        readEnvironment { reader(Metrics(polygon: self, environment: $0)) }
    }
}
