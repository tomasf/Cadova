import Foundation

/// A direction along an axis
public enum AxisDirection: Sendable, Hashable, CaseIterable {
    /// The positive direction along an axis (pointing towards positive infinity)
    case positive
    /// The negative direction along an axis (pointing towards negative infinity)
    case negative

    /// Represents the minimum direction along an axis, which corresponds to the `.negative` direction.
    /// This alias can be used to improve readability in contexts where "minimum" or "low" values
    /// are conceptually aligned with the `.negative` direction.
    public static let min = negative

    /// Represents the maximum direction along an axis, which corresponds to the `.positive` direction.
    /// This alias can be used to improve readability in contexts where "maximum" or "high" values
    /// are conceptually aligned with the `.positive` direction.
    public static let max = positive

    internal var factor: Double {
        self == .negative ? -1 : 1
    }
}

