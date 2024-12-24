import Foundation

public struct GeometryAlignment<D: Dimensionality>: Equatable, Sendable {
    internal let values: DimensionalValues<AxisAlignment?, D>

    private init(_ values: DimensionalValues<AxisAlignment?, D>) {
        self.values = values
    }

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) where D == Dimensionality2 {
        values = .init(x: x, y: y)
    }

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) where D == Dimensionality3 {
        values = .init(x: x, y: y, z: z)
    }

    public init(all value: AxisAlignment?) {
        values = .init { _ in value }
    }

    internal init(merging alignments: [Self]) {
        values = .init { index in
            alignments.compactMap { $0[index] }.last
        }
    }

    public subscript(axis: D.Axis) -> AxisAlignment? {
        values[axis]
    }

    public func with(axis: D.Axis, as newValue: AxisAlignment) -> Self {
        .init(values.map { $0 == axis ? newValue : $1 })
    }

    internal var factors: D.Vector {
        values.map { $0?.factor ?? 0 }.vector
    }

    internal func defaultingToOrigin() -> Self {
        .init(values.map { $0 ?? .min })
    }

    internal var hasEffect: Bool {
        values.contains { $0 != nil }
    }
}

public typealias GeometryAlignment2D = GeometryAlignment<Dimensionality2>
public typealias GeometryAlignment3D = GeometryAlignment<Dimensionality3>

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}
