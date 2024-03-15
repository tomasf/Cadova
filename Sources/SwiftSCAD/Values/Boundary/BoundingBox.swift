import Foundation

public typealias BoundingBox2D = BoundingBox<Vector2D>
public typealias BoundingBox3D = BoundingBox<Vector3D>

/// An axis-aligned bounding volume defined by its minimum and maximum corners, used to calculate and represent the bounding area or volume of shapes or points in a generic vector space.
public struct BoundingBox<V: Vector> {
    /// The minimum corner point of the bounding volume, typically representing the "lower" corner in geometric space.
    public let minimum: V
    /// The maximum corner point of the bounding volume, typically representing the "upper" corner in geometric space.
    public let maximum: V

    /// Initializes a new `BoundingBox` with the specified minimum and maximum points.
    /// - Parameters:
    ///   - minimum: The minimum corner point of the bounding volume.
    ///   - maximum: The maximum corner point of the bounding volume.
    init(minimum: V, maximum: V) {
        self.minimum = minimum
        self.maximum = maximum
    }

    static var zero: Self { .init(minimum: .zero, maximum: .zero) }

    /// Initializes a new `BoundingBox` enclosing a single point.
    /// - Parameter vector: The vector used for both the minimum and maximum points.
    init(_ vector: V) {
        self.init(minimum: vector, maximum: vector)
    }

    /// Initializes a `BoundingBox` from a sequence of vectors. It efficiently calculates the minimum and maximum vectors that enclose all vectors in the sequence.
    /// - Parameter sequence: A sequence of vectors.
    public init<S: Sequence<V>>(_ sequence: S) {
        let points = Array(sequence)
        guard let firstVector = points.first else {
            preconditionFailure("BoundingBox requires at least one vector in the sequence.")
        }

        self.init(
            minimum: points.reduce(firstVector, V.min),
            maximum: points.reduce(firstVector, V.max)
        )
    }

    /// Expands the bounding volume to include the given vector.
    /// - Parameter vector: The vector point to include in the bounding volume.
    /// - Returns: A new `BoundingBox` that includes the original volume and the specified vector.
    public func adding(_ vector: V) -> BoundingBox<V> {
        .init(
            minimum: V(elements: zip(minimum.elements, vector.elements).map { min($0, $1) }),
            maximum: V(elements: zip(maximum.elements, vector.elements).map { max($0, $1) })
        )
    }
}

extension BoundingBox {
    public var size: V {
        maximum - minimum
    }

    public var center: V {
        minimum + size / 2.0
    }

    public func intersection(with other: BoundingBox<V>) -> BoundingBox {
        .init(minimum: V.max(minimum, other.minimum), maximum: V.min(maximum, other.maximum))
    }

    public func offset(_ expansion: V) -> BoundingBox {
        .init(minimum: minimum - expansion, maximum: maximum + expansion)
    }
}
