import Foundation

/// Defines methods for adjusting circular shapes to avoid steep overhangs when 3D printed horizontally.
/// These adjustments help improve printability without the need for support structures.
public enum CircularOverhangMethod: Sendable {
    /// No adjustment is made. The shape remains a pure circle, which may lead to steep unsupported overhangs.
    case none

    /// Adds a pointed extension to the top of the circle, forming a full teardrop shape.
    /// This effectively reduces overhang angles and improves printability.
    case teardrop

    /// Flattens the top of the circle to create a bridgeable surface.
    /// Retains a more circular appearance while making the shape easier to print without support.
    case bridge
}

public extension EnvironmentValues {
    private static let key = Key("Cadova.CircularOverhangMethod")

    /// The circular overhang method to apply when adjusting shapes like circles or cylinders
    /// for improved printability. Defaults to `.none` if not explicitly set.
    var circularOverhangMethod: CircularOverhangMethod {
        get { self[Self.key] as? CircularOverhangMethod ?? .none }
        set { self[Self.key] = newValue }
    }

    /// Returns a copy of the environment with the given circular overhang method applied.
    ///
    /// - Parameter style: The method to use for overhang relief. If `nil`, the existing value is preserved.
    func withCircularOverhangMethod(_ style: CircularOverhangMethod?) -> EnvironmentValues {
        return setting(key: Self.key, value: style)
    }
}

public extension Geometry {
    /// Returns a new geometry with the given circular overhang method applied to its environment.
    ///
    /// - Parameter method: The overhang method to apply.
    func withCircularOverhangMethod(_ method: CircularOverhangMethod) -> D.Geometry {
        withEnvironment { enviroment in
            enviroment.withCircularOverhangMethod(method)
        }
    }
}
