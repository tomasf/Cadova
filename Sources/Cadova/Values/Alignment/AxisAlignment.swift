import Foundation

/// Specifies alignment along a single axis.
///
/// Use `AxisAlignment` to indicate where geometry should be positioned relative to its
/// bounding box along one axis. This is typically combined with ``GeometryAlignment`` to
/// specify alignment across multiple axes.
///
public enum AxisAlignment: Equatable, Hashable, Sendable {
    /// Align to the minimum edge (e.g., left, front, or bottom).
    case min

    /// Align to the center.
    case mid

    /// Align to the maximum edge (e.g., right, back, or top).
    case max

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
