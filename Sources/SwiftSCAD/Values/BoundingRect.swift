import Foundation

public struct BoundingRect {
    public let minimum: Vector2D
    public let maximum: Vector2D

    init(minimum: Vector2D, maximum: Vector2D) {
        self.minimum = minimum
        self.maximum = maximum
    }

    init(_ vector: Vector2D) {
        self.init(minimum: vector, maximum: vector)
    }

    init<S: Sequence<Vector2D>>(_ sequence: S) {
        let vectors = Array(sequence)
        guard let first = vectors.first else {
            preconditionFailure("BoundingRect needs at least one vector")
        }

        self = vectors.reduce(.init(first)) { $0.adding($1) }
    }

    func adding(_ vector: Vector2D) -> BoundingRect {
        .init(
            minimum: [min(minimum.x, vector.x), min(minimum.y, vector.y)],
            maximum: [max(maximum.x, vector.x), max(maximum.y, vector.y)]
        )
    }

    var corners: [Vector2D] {[
        minimum,
        [maximum.x, minimum.y],
        maximum,
        [minimum.x, maximum.y]
    ]}
}
