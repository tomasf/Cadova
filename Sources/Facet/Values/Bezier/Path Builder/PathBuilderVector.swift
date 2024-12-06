import Foundation

internal struct PathBuilderVector<V: Vector>: Sendable {
    private let values: DimensionalValues<PositionedValue, V>

    private init(_ values: DimensionalValues<PositionedValue, V>) {
        self.values = values
    }

    init(_ vector: V) {
        values = .init {
            PositionedValue(value: vector[$0], mode: nil)
        }
    }

    init(_ x: any PathBuilderValue, _ y: any PathBuilderValue) where V == Vector2D {
        values = .init(x: x.positionedValue, y: y.positionedValue)
    }

    init(_ x: any PathBuilderValue, _ y: any PathBuilderValue, _ z: any PathBuilderValue) where V == Vector3D {
        values = .init(x: x.positionedValue, y: y.positionedValue, z: z.positionedValue)
    }

    func withDefaultMode(_ mode: PathBuilderPositioning) -> Self {
        .init(values.map { $1.withDefaultMode(mode) })
    }

    func value(relativeTo base: V, defaultMode: PathBuilderPositioning) -> V {
        values.map {
            $1.value(relativeTo: base[$0], defaultMode: defaultMode)
        }.vector
    }
}
