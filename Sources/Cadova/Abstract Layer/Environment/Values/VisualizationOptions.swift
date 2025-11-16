import Foundation

internal enum VisualizationOptionKey {
    case scale
    case primaryColor
    case labelsEnabled
    case labelDirection
    case controlPointsEnabled
    case controlPointsColor
}

internal extension EnvironmentValues {
    private static let key = Key("Cadova.VisualizationOptions")

    var visualizationOptions: [VisualizationOptionKey: any Sendable] {
        get { self[Self.key] as? [VisualizationOptionKey: any Sendable] ?? [:] }
        set { self[Self.key] = newValue }
    }
}

internal extension [VisualizationOptionKey: any Sendable] {
    var scale: Double? { self[.scale] as? Double }
    var primaryColor: Color? { self[.primaryColor] as? Color }
    var labelsEnabled: Bool? { self[.labelsEnabled] as? Bool }
    var labelDirection: Direction3D? { self[.labelDirection] as? Direction3D }
    var controlPointsEnabled: Bool? { self[.controlPointsEnabled] as? Bool }
    var controlPointsColor: Color? { self[.controlPointsColor] as? Color }
}

fileprivate extension Geometry {
    func withVisualizationOption(_ key: VisualizationOptionKey, value: (any Sendable)?) -> D.Geometry {
        withEnvironment { $0.visualizationOptions[key] = value }
    }
}

public extension Geometry {
    /// Sets the visualization scale for helper/diagnostic geometry derived from this geometry.
    ///
    /// Use this to make visualizations appear larger or smaller relative to the model, without affecting the model itself.
    /// A value of `1.0` means default size; values greater than `1.0` enlarge visualizations; values less than `1.0` shrink them.
    ///
    /// - Parameter scale: The relative scale to apply to visualization elements.
    /// - Returns: Geometry with the visualization scale applied in its environment.
    func withVisualizationScale(_ scale: Double) -> D.Geometry {
        withVisualizationOption(.scale, value: scale)
    }

    /// Sets the primary visualization color used by helper/diagnostic elements.
    ///
    /// Depending on the type of visualization, this color may be used for outlines, markers, or text.
    /// This does not affect the material or color of the model itself.
    ///
    /// - Parameter color: The color to use for visualization elements.
    /// - Returns: Geometry with the visualization color applied in its environment.
    func withVisualizationColor(_ color: Color) -> D.Geometry {
        withVisualizationOption(.primaryColor, value: color)
    }

    /// Controls whether visualization labels are hidden.
    ///
    /// Pass `true` to hide labels, or `false` to show them. The default behavior is visualization-dependent.
    ///
    /// - Parameter hidden: Whether labels should be hidden.
    /// - Returns: Geometry with the label visibility preference applied in its environment.
    func withVisualizationLabels(hidden: Bool) -> D.Geometry {
        withVisualizationOption(.labelsEnabled, value: !hidden)
    }

    /// Sets the facing direction for visualization labels.
    ///
    /// Some visualizations display text or arrows that can be oriented. Use this to influence which direction
    /// labels should face.
    ///
    /// - Parameter direction: The desired facing direction for labels.
    /// - Returns: Geometry with the label facing preference applied in its environment.
    func withVisualizationLabels(facing direction: Direction3D) -> D.Geometry {
        withVisualizationOption(.labelDirection, value: direction)
    }

    /// Controls whether visualization control points are hidden.
    ///
    /// Pass `true` to hide control points/handles, or `false` to show them. The default behavior is visualization-dependent.
    ///
    /// - Parameter hidden: Whether control points should be hidden.
    /// - Returns: Geometry with the control point visibility preference applied in its environment.
    func withVisualizationControlPoints(hidden: Bool) -> D.Geometry {
        withVisualizationOption(.controlPointsEnabled, value: !hidden)
    }

    /// Sets the color used for visualization control points.
    ///
    /// This color applies to helper markers such as control points or handles and does not affect the model itself.
    ///
    /// - Parameter color: The color to use for control points.
    /// - Returns: Geometry with the control point color preference applied in its environment.
    func withVisualizationControlPoints(color: Color) -> D.Geometry {
        withVisualizationOption(.controlPointsColor, value: color)
    }
}
