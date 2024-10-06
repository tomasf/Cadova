import Foundation

public enum AxisAlignment: Equatable, Sendable {
    case min
    case mid
    case max

    internal var factor: Double {
        switch self {
        case .min: 0.0
        case .mid: 0.5
        case .max: 1.0
        }
    }
}
