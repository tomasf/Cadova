import Foundation
import Manifold3D

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.FillRule")

    var fillRule: FillRule {
        self[Self.environmentKey] as? FillRule ?? .default
    }

    func withFillRule(_ fillRule: FillRule) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: fillRule)
    }
}

public enum FillRule: Hashable, Sendable {
    case nonZero
    case evenOdd
    case positive
    case negative

    static var `default`: FillRule { .nonZero }

    internal var primitive: CrossSection.FillRule {
        switch self {
        case .nonZero: return .nonZero
        case .evenOdd: return .evenOdd
        case .positive: return .positive
        case .negative: return .negative
        }
    }
}

public extension Geometry2D {
    func usingFillRule(_ fillRule: FillRule) -> Geometry2D {
        withEnvironment { $0.withFillRule(fillRule) }
    }
}

public extension Geometry3D {
    func usingFillRule(_ fillRule: FillRule) -> Geometry3D {
        withEnvironment { $0.withFillRule(fillRule) }
    }
}
