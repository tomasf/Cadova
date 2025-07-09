import Foundation
import Manifold3D

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.FillRule")

    /// The fill rule used for determining polygon interiors in this environment.
    ///
    /// Defaults to `.nonZero` if not explicitly set.
    var fillRule: FillRule {
        get { self[Self.environmentKey] as? FillRule ?? .default }
        set { self[Self.environmentKey] = newValue }
    }

    /// Returns a copy of the environment with the specified fill rule applied.
    ///
    /// Use this to control how complex polygon fills are computed in geometric operations.
    func withFillRule(_ fillRule: FillRule) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: fillRule)
    }
}

/// Describes how the interior of a polygon is determined when filling complex shapes.
///
/// Fill rules determine which parts of a shape are considered "inside" when it contains self-intersections
/// or multiple overlapping paths. Most of these rules rely on the concept of a winding number — an integer
/// representing how many times a path winds around a given point.
///
/// The winding number is calculated by tracing the direction of edges around a point: each counter-clockwise
/// traversal adds one, and each clockwise traversal subtracts one. The result determines whether the point
/// lies inside the shape depending on the selected fill rule.
///
/// The default fill rule is `.nonZero`.
public enum FillRule: Hashable, Sendable, Codable {
    /// The classic non-zero winding rule. Areas enclosed by paths whose winding number is non-zero are filled.
    case nonZero
    /// Areas enclosed by an odd number of overlapping paths are filled.
    case evenOdd
    /// Only regions with a positive winding number are filled.
    case positive
    /// Only regions with a negative winding number are filled.
    case negative

    fileprivate static var `default`: FillRule { .nonZero }

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
    /// Returns a copy of the geometry with the given fill rule set in the environment.
    ///
    /// This affects how polygons within the geometry are interpreted when determining filled regions.
    func withFillRule(_ fillRule: FillRule) -> D.Geometry {
        withEnvironment { $0.withFillRule(fillRule) }
    }
}
