import Foundation
import Manifold3D

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.FillRule")

    var fillRule: FillRule {
        get { self[Self.environmentKey] as? FillRule ?? .default }
        set { self[Self.environmentKey] = newValue }
    }

    func withFillRule(_ fillRule: FillRule) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: fillRule)
    }
}

public enum FillRule: Hashable, Sendable, Codable {
    case nonZero
    case evenOdd
    case positive
    case negative

    static var `default`: FillRule { .nonZero }

    internal var manifoldRepresentation: CrossSection.FillRule {
        switch self {
        case .nonZero: return .nonZero
        case .evenOdd: return .evenOdd
        case .positive: return .positive
        case .negative: return .negative
        }
    }
}

public extension Geometry {
    func usingFillRule(_ fillRule: FillRule) -> D.Geometry {
        withEnvironment { $0.withFillRule(fillRule) }
    }
}
