import Foundation

public typealias Boundary2D = Boundary<Vector2D>
public typealias Boundary3D = Boundary<Vector3D>

public struct Boundary<V: Vector> {
    internal let points: [V]

    internal init(points: [V]) {
        self.points = points
    }
}

internal extension Boundary {
    static var empty: Boundary { .init(points: []) }

    static func points(_ points: [V]) -> Boundary {
        Self(points: points)
    }

    static func union(_ boundaries: [Boundary]) -> Boundary {
        .init(points: boundaries.flatMap(\.points))
    }

    init(boundingBox: BoundingBox<V>) {
        self = .box(boundingBox.size).translated(boundingBox.minimum)
    }

    var boundingBox: BoundingBox<V>? {
        isEmpty ? nil : BoundingBox(points)
    }
}

internal extension Boundary {
    func map<OutputV: Vector>(_ function: (V) -> OutputV) -> Boundary<OutputV> {
        .init(points: points.map(function))
    }

    func map<OutputV: Vector>(_ function: (V) -> [OutputV]) -> Boundary<OutputV> {
        .init(points: points.flatMap(function))
    }

    func translated(_ translation: V) -> Boundary<V> {
        transformed(.translation(translation))
    }

    func transformed(_ transform: V.Transform) -> Boundary<V> {
        map { transform.apply(to: $0) }
    }

    func min(_ axis: V.Axes.Axis) -> Double? {
        points.map { $0[axis] }.min()
    }

    func max(_ axis: V.Axes.Axis) -> Double? {
        points.map { $0[axis] }.max()
    }

    var isEmpty: Bool {
        points.isEmpty
    }

    func scaleOffset(_ amount: Double) -> Boundary {
        guard let box = boundingBox else { return self }
        return self
            .translated(-box.center)
            .transformed(.scaling((box.size + amount * 2) / box.size))
            .translated(box.center)
    }

    func minkowskiSum(_ other: Boundary) -> Boundary {
        .points(points.flatMap { point in
            other.points.map { $0 + point }
        })
    }
}

internal extension Boundary {
    enum MergeStrategy {
        case union
        case boxIntersection
        case first
        case minkowskiSum
        case custom (([Boundary]) -> Boundary)

        func apply(_ bounds: [Boundary]) -> Boundary {
            switch self {
            case .union:
                .union(bounds)
            case .boxIntersection:
                bounds.compactMap(\.boundingBox)
                    .reduce { $0.intersection(with: $1) ?? .zero }
                    .map { Boundary(boundingBox: $0) }
                ?? .empty
            case .first:
                bounds.first ?? .empty
            case .minkowskiSum:
                bounds.reduce { $0.minkowskiSum($1) } ?? .empty
            case .custom (let function):
                function(bounds)
            }
        }
    }
}
