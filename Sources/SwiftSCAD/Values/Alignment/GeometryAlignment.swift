import Foundation

public struct GeometryAlignment<V: Vector>: Equatable, Sendable {
    internal let values: DimensionalValues<AxisAlignment?, V>

    private init(_ values: DimensionalValues<AxisAlignment?, V>) {
        self.values = values
    }

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) where V == Vector2D {
        values = .init(x: x, y: y)
    }

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) where V == Vector3D {
        values = .init(x: x, y: y, z: z)
    }

    fileprivate init(merging alignments: [Self]) {
        values = .init { index in
            alignments.compactMap { $0[index] }.last
        }
    }

    public subscript(axis: V.Axes.Axis) -> AxisAlignment? {
        values[axis]
    }

    internal var factors: V {
        values.map { $0?.factor ?? 0 }.vector
    }

    internal func defaultingToOrigin() -> Self {
        .init(values.map { $0 ?? .min })
    }

    internal var hasEffect: Bool {
        values.contains { $0 != nil }
    }
}

public typealias GeometryAlignment2D = GeometryAlignment<Vector2D>
public typealias GeometryAlignment3D = GeometryAlignment<Vector3D>

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}
