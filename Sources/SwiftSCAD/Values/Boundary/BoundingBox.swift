import Foundation

public typealias BoundingBox2D = BoundingBox<Vector2D>
public typealias BoundingBox3D = BoundingBox<Vector3D>

/// An axis-aligned bounding volume defined by its minimum and maximum corners, used to calculate and represent the bounding area or volume of shapes or points in a generic vector space.
public struct BoundingBox<V: Vector>: Sendable {
    /// The minimum corner point of the bounding volume, typically representing the "lower" corner in geometric space.
    public let minimum: V
    /// The maximum corner point of the bounding volume, typically representing the "upper" corner in geometric space.
    public let maximum: V

    /// Initializes a new `BoundingBox` with the specified minimum and maximum points.
    /// - Parameters:
    ///   - minimum: The minimum corner point of the bounding volume.
    ///   - maximum: The maximum corner point of the bounding volume.
    public init(minimum: V, maximum: V) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public static var zero: Self { .init(.zero) }

    /// Initializes a new `BoundingBox` enclosing a single point.
    /// - Parameter vector: The vector used for both the minimum and maximum points.
    public init(_ vector: V) {
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

    public init(union boxes: [BoundingBox]) {
        self.init(boxes.flatMap { [$0.minimum, $0.maximum] })
    }

    /// Expands the bounding volume to include the given vector.
    /// - Parameter vector: The vector point to include in the bounding volume.
    /// - Returns: A new `BoundingBox` that includes the original volume and the specified vector.
    public func adding(_ vector: V) -> BoundingBox<V> {
        .init(
            minimum: V(elements: zip(minimum, vector).map(min)),
            maximum: V(elements: zip(maximum, vector).map(max))
        )
    }
}

extension BoundingBox {
    /// The size of the bounding volume.
    ///
    /// This property calculates the size of the bounding volume as the difference between its maximum and minimum points, representing the volume's dimensions in each axis.
    public var size: V {
        maximum - minimum
    }

    /// The center point of the bounding volume.
    ///
    /// This property calculates the center of the bounding volume, which is halfway between the minimum and maximum points. It represents the geometric center of the volume.
    public var center: V {
        minimum + size / 2.0
    }

    /// Accesses the range of values in the specified axis within the bounding box.
    ///
    /// This subscript returns the range of coordinates along the provided axis (e.g., x, y, or z for a 3D bounding box).
    /// The range is defined by the bounding box's minimum and maximum values along that axis.
    ///
    /// - Parameter axis: The axis for which to retrieve the coordinate range.
    /// - Returns: A `Range<Double>` representing the minimum to maximum coordinates along the given axis.
    ///
    public subscript(_ axis: V.Axis) -> Range<Double> {
        .init(minimum[axis], maximum[axis])
    }

    /// Determines whether the bounding box is valid.
    ///
    /// A bounding box is considered valid if it represents a real geometric area or volume, which means all its dimensions must be non-negative. This property checks that the size of the bounding box in each dimension is greater than or equal to zero, ensuring the box does not represent an inverted or non-existent space.
    public var isValid: Bool {
        !size.contains { $0 < 0 }
    }

    /// Calculates the intersection of this bounding volume with another.
    ///
    /// This method returns a new `BoundingBox` representing the volume that is common to both this and another bounding volume. If the bounding volumes do not intersect, the result is a bounding volume with zero size at the point of closest approach.
    /// - Parameter other: The other bounding volume to intersect with.
    /// - Returns: A `BoundingBox` representing the intersection of the two volumes.
    public func intersection(with other: BoundingBox<V>) -> BoundingBox? {
        let overlap = BoundingBox(minimum: V.max(minimum, other.minimum), maximum: V.min(maximum, other.maximum))
        return overlap.isValid ? overlap : nil
    }

    /// Expands or contracts the bounding volume.
    ///
    /// This method returns a new `BoundingBox` that has been expanded or contracted by the specified vector. The expansion occurs outward from the center in all dimensions if the vector's components are positive, and inward if they are negative.
    /// - Parameter expansion: The vector by which to expand or contract the bounding volume.
    /// - Returns: A `BoundingBox` that has been offset by the expansion vector.
    public func offset(_ expansion: V) -> BoundingBox {
        .init(minimum: minimum - expansion, maximum: maximum + expansion)
    }

    public func transformed(_ transform: V.Transform) -> BoundingBox {
        .init([transform.apply(to: minimum), transform.apply(to: maximum)])
    }
}

extension BoundingBox {
    func translation(for alignment: GeometryAlignment<V>) -> V {
        alignment.values.map { axis, axisAlignment in
            axisAlignment?.translation(origin: minimum[axis], size: size[axis]) ?? 0
        }.vector
    }
}

extension BoundingBox: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[min: \(minimum), max: \(maximum)]"
    }
}

extension BoundingBox2D? {
    func requireNonNil() -> BoundingBox2D {
        guard let box = self else {
            preconditionFailure("Bounding box was empty")
        }
        return box
    }
}

extension BoundingBox3D? {
    func requireNonNil() -> BoundingBox3D {
        guard let box = self else {
            preconditionFailure("Bounding box was empty")
        }
        return box
    }
}
