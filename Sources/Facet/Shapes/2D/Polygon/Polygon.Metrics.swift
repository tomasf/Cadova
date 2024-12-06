import Foundation

fileprivate extension [Vector2D] {
    var length: Double {
        paired().map { $0.distance(to: $1) }.reduce(0, +)
    }

    var area: Double {
        abs(
            wrappedPairs()
                .map { $0.x * $1.y - $0.y * $1.x }
                .reduce(0, +)
        ) / 2.0
    }

    var boundingBox: BoundingBox2D {
        .init(self)
    }
}

public extension Polygon {
    struct Metrics {
        public let points: [Vector2D]
        public let boundingBox: BoundingBox2D
        public let length: Double
        public let area: Double

        internal init(points: [Vector2D]) {
            self.points = points
            self.boundingBox = points.boundingBox
            self.length = points.length
            self.area = points.area
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

    /// Calculates the bounding rectangle of the polygon within a given environment.
    /// - Parameter environment: The environment context.
    /// - Returns: A `BoundingRect2D` representing the smallest rectangle enclosing the polygon.
    func boundingRect(in environment: EnvironmentValues) -> BoundingBox2D {
        .init(points(in: environment))
    }

    /// Calculates the length (perimeter, if closed) of the polygon within a given environment.
    /// - Parameter environment: The environment context.
    /// - Returns: The total length of the polygon as a `Double`.
    func length(in environment: EnvironmentValues) -> Double {
        points(in: environment).length
    }

    /// Calculates the area of the polygon within a given environment.
    /// - Parameter environment: The environment context.
    /// - Returns: The area of the polygon as a `Double`.
    func area(in environment: EnvironmentValues) -> Double {
        points(in: environment).area
    }

    /// Reads and provides metrics (points, bounding box, length, area) for the polygon and allows
    /// further geometry processing in a 2D environment.
    /// - Parameter reader: A closure receiving `Metrics` of the polygon and returning a 2D geometry.
    /// - Returns: A 2D geometry result from the reader closure.
    func readMetrics(@GeometryBuilder2D _ reader: @escaping (Metrics) -> any Geometry2D) -> any Geometry2D {
        readEnvironment { e in
            reader(Metrics(points: points(in: e)))
        }
    }

    /// Reads and provides metrics (points, bounding box, length, area) for the polygon and allows
    /// further geometry processing in a 3D environment.
    /// - Parameter reader: A closure receiving `Metrics` of the polygon and returning a 3D geometry.
    /// - Returns: A 3D geometry result from the reader closure.
    func readMetrics(@GeometryBuilder3D _ reader: @escaping (Metrics) -> any Geometry3D) -> any Geometry3D {
        readEnvironment { e in
            reader(Metrics(points: points(in: e)))
        }
    }
}
