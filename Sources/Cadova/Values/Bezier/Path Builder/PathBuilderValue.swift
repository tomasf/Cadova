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
