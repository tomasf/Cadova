import Foundation

public enum AxisAlignment: Equatable, Hashable, Sendable {
    case min, mid, max

    /// A normalized fraction representing the alignment position along an axis.
    ///
    /// The value is expressed as a proportion of the axis span:
    /// - `.min` → `0.0`, representing the minimum boundary.
    /// - `.mid` → `0.5`, representing the midpoint.
    /// - `.max` → `1.0`, representing the maximum boundary.
    ///
    /// This value can be used for calculations such as positioning, interpolation,
    /// or alignment transforms relative to a geometry’s size.
    public var fraction: Double {
        switch self {
        case .min: 0.0
        case .mid: 0.5
        case .max: 1.0
        }
    }

    internal func translation(origin: Double, size: Double) -> Double {
        -origin - size * fraction
    }
}
