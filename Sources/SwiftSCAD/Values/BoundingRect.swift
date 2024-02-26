import Foundation

/// A rectangle defined by its minimum and maximum corners, used to calculate and represent the bounding area of shapes or points.
public struct BoundingRect {
    /// The minimum corner point of the rectangle, typically the bottom left corner.
    public let minimum: Vector2D
    /// The maximum corner point of the rectangle, typically the top right corner.
    public let maximum: Vector2D

    /// Initializes a new `BoundingRect` with the specified minimum and maximum points.
    /// - Parameters:
    ///   - minimum: The minimum corner point of the rectangle.
    ///   - maximum: The maximum corner point of the rectangle.
    init(minimum: Vector2D, maximum: Vector2D) {
        self.minimum = minimum
        self.maximum = maximum
    }

    /// Initializes a new `BoundingRect` enclosing a single point.
    /// - Parameter vector: The vector used for both the minimum and maximum points.
    init(_ vector: Vector2D) {
        self.init(minimum: vector, maximum: vector)
    }

    /// Initializes a `BoundingRect` from a sequence of `Vector2D` points.
    /// It calculates the minimum and maximum corners that enclose all the points.
    /// - Parameter sequence: A sequence of `Vector2D` points.
    init<S: Sequence<Vector2D>>(_ sequence: S) {
        let vectors = Array(sequence)
        guard let first = vectors.first else {
            preconditionFailure("BoundingRect needs at least one vector")
        }

        self = vectors.reduce(.init(first)) { $0.adding($1) }
    }

    /// Expands the rectangle to include the given vector.
    /// - Parameter vector: The `Vector2D` point to include in the rectangle.
    /// - Returns: A new `BoundingRect` that includes the original rectangle and the specified vector.
    func adding(_ vector: Vector2D) -> BoundingRect {
        .init(
            minimum: [min(minimum.x, vector.x), min(minimum.y, vector.y)],
            maximum: [max(maximum.x, vector.x), max(maximum.y, vector.y)]
        )
    }

    /// A collection of the rectangle's corners
    var corners: [Vector2D] {[
        minimum,
        [maximum.x, minimum.y],
        maximum,
        [minimum.x, maximum.y]
    ]}
}
