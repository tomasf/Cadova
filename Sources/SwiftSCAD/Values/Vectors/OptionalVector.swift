import Foundation

internal typealias OptionalVector<V: Vector> = DimensionalValue<Double?, V>

extension OptionalVector where Element == Double? {
    func vector(with defaults: V) -> V {
        mapVector { index, value in
            value ?? defaults[index]
        }
    }

    init(_ vector: V) {
        self.init(vector.elements)
    }
}

extension OptionalVector<Vector2D> {
    init(x: Double?, y: Double?) {
        self.init(x, y)
    }
}
extension OptionalVector<Vector3D> {
    init(x: Double?, y: Double?, z: Double?) {
        self.init(x, y, z)
    }
}
