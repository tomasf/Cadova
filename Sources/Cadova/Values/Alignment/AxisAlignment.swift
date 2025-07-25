import Foundation

public enum AxisAlignment: Equatable, Hashable, Sendable {
    case min, mid, max

    internal var factor: Double {
        switch self {
        case .min: 0.0
        case .mid: 0.5
        case .max: 1.0
        }
    }

    internal func translation(origin: Double, size: Double) -> Double {
        -origin - size * factor
    }
}
