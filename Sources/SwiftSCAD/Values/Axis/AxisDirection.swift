import Foundation

/// A direction along an axis
public enum AxisDirection: Sendable, Hashable, CaseIterable {
    /// The positive direction along an axis (pointing towards positive infinity)
    case positive
    /// The negative direction along an axis (pointing towards negative infinity)
    case negative

    public static let min = negative
    public static let max = positive

    internal var factor: Double {
        self == .negative ? -1 : 1
    }
}

