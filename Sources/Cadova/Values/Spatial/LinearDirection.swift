import Foundation

/// A directional value used to represent movement or orientation along a line.
///
/// This type expresses a simple binary direction: forward (`.positive`) or backward (`.negative`),
/// typically used when working with one-dimensional or aligned behaviors.
public enum LinearDirection: Sendable, Hashable, CaseIterable, Comparable {
    /// The forward or increasing direction (typically toward positive infinity).
    case positive
    /// The backward or decreasing direction (typically toward negative infinity).
    case negative

    /// Alias for `.negative`. Useful in contexts where this direction represents a lower bound or minimum.
    public static let min = negative

    /// Alias for `.positive`. Useful in contexts where this direction represents an upper bound or maximum.
    public static let max = positive

    internal var factor: Double {
        self == .negative ? -1 : 1
    }

    public static func < (lhs: LinearDirection, rhs: LinearDirection) -> Bool {
        lhs == .negative && rhs == .positive
    }
}
