import Foundation

public protocol PathBuilderValue: Sendable {}

extension Double: PathBuilderValue {
    public var relative: any PathBuilderValue {
        PositionedValue(value: self, mode: .relative)
    }

    public var absolute: any PathBuilderValue {
        PositionedValue(value: self, mode: .absolute)
    }
}

public extension PathBuilderValue where Self == Double {
    static var unchanged: any PathBuilderValue { 0.relative }
}

internal struct PositionedValue: PathBuilderValue {
    var value: Double
    var mode: PathBuilderPositioning?

    func value(relativeTo base: Double, defaultMode: PathBuilderPositioning) -> Double {
        switch mode ?? defaultMode {
        case .relative: base + value
        case .absolute: value
        }
    }

    func withDefaultMode(_ defaultMode: PathBuilderPositioning) -> PositionedValue {
        .init(value: value, mode: mode ?? defaultMode)
    }
}

internal extension PathBuilderValue {
    var positionedValue: PositionedValue {
        if let self = self as? Double {
            PositionedValue(value: self, mode: nil)
        } else if let self = self as? PositionedValue {
            self
        } else {
            preconditionFailure("Unknown BezierBuilderValue type.")
        }
    }
}

internal typealias PathBuilderVector<V: Vector> = DimensionalValues<PositionedValue, V>

internal extension PathBuilderVector where Element == PositionedValue {
    init(_ vector: V) {
        self.init {
            PositionedValue(value: vector[$0], mode: nil)
        }
    }

    init(_ x: any PathBuilderValue, _ y: any PathBuilderValue) where V == Vector2D {
        self.init(x: x.positionedValue, y: y.positionedValue)
    }

    init(_ x: any PathBuilderValue, _ y: any PathBuilderValue, _ z: any PathBuilderValue) where V == Vector3D {
        self.init(x: x.positionedValue, y: y.positionedValue, z: z.positionedValue)
    }

    func withDefaultMode(_ mode: PathBuilderPositioning) -> Self {
        map { $1.withDefaultMode(mode) }
    }

    func value(relativeTo base: V, defaultMode: PathBuilderPositioning) -> V {
        map {
            $1.value(relativeTo: base[$0], defaultMode: defaultMode)
        }.vector
    }
}
