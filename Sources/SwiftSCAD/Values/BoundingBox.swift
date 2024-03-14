import Foundation

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

    public var size: V {
        maximum - minimum
    }

    public var center: V {
        minimum + size / 2.0
    }
}

public typealias BoundingBox2D = BoundingBox<Vector2D>
public typealias BoundingBox3D = BoundingBox<Vector3D>

public extension BoundingBox2D {
    @UnionBuilder2D
    func visualized(borderWidth: Double = 1.0) -> any Geometry2D {
        let half = Union {
            Rectangle([maximum.x - minimum.x + borderWidth * 2, borderWidth])
            Rectangle([borderWidth, maximum.y - minimum.y + borderWidth * 2])
        }.translated(x: -borderWidth, y: -borderWidth)
        Union {
            half.translated(minimum)
            half.flipped(along: .all)
                .translated(maximum)
        }
        .colored(.blue)
    }
}

public extension BoundingBox3D {
    func visualized(borderWidth: Double = 1.0) -> any Geometry3D {
        let size = maximum - minimum

        func frame(_ size: Vector2D) -> any Geometry3D {
            Rectangle(size)
                .offset(amount: 0.001, style: .bevel)
                .subtracting {
                    Rectangle(size)
                        .offset(amount: -borderWidth, style: .miter)
                }
                .extruded(height: borderWidth)
        }

        let half = Union {
            frame([size.x, size.y])
            frame([size.x, size.z])
                .rotated(x: 90°)
                .translated(y: borderWidth)
            frame([size.z, size.y])
                .rotated(y: -90°)
                .translated(x: borderWidth)
        }

        return half
            .translated(minimum)
            .adding {
                half.flipped(along: .all)
                    .translated(maximum)
            }
        .colored(.blue)
        .background()
    }
}

extension Boundary3D {
    func visualized() -> any Geometry3D {
        points.mapUnion {
            Box([0.1, 0.1, 0.1], center: .all)
                .translated($0)
        }
        .colored(.red)
        .background()
    }
}

extension Boundary2D {
    func visualized() -> any Geometry2D {
        points.mapUnion {
            Rectangle([0.1, 0.1], center: .all)
                .translated($0)
        }
        .colored(.red)
        .background()
    }
}

extension Axes3D {
    var axisArray: [Axis3D] {
        [contains(axis: .x) ? Axis3D.x : nil,
         contains(axis: .y) ? Axis3D.y : nil,
         contains(axis: .z) ? Axis3D.z : nil]
            .compactMap { $0 }
    }
}
