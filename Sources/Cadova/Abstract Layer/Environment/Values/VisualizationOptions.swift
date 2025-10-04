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

fileprivate extension Geometry {
    func withVisualizationOption(_ key: VisualizationOptionKey, value: (any Sendable)?) -> D.Geometry {
        withEnvironment { $0.visualizationOptions[key] = value }
    }
}

public extension Geometry {
    // set the scale of visualization geometry. The default scale is 1.0. If the visualization is too small or large in relation
    // to your model, decrease or increase this value
    func withVisualizationScale(_ scale: Double) -> D.Geometry {
        withVisualizationOption(.scale, value: scale)
    }

    // sets the primary color of visualizations. this can be applied in different ways depending on the type of visualization
    func withVisualizationColor(_ color: Color) -> D.Geometry {
        withVisualizationOption(.primaryColor, value: color)
    }

    // are labels hidden?
    func withVisualizationLabels(hidden: Bool) -> D.Geometry {
        withVisualizationOption(.labelsEnabled, value: !hidden)
    }

    // which direction are visualization labels facing?
    func withVisualizationLabels(facing direction: Direction3D) -> D.Geometry {
        withVisualizationOption(.labelDirection, value: direction)
    }

    // hide control points?
    func withVisualizationControlPoints(hidden: Bool) -> D.Geometry {
        withVisualizationOption(.controlPointsEnabled, value: !hidden)
    }

    // control point color
    func withVisualizationControlPoints(color: Color) -> D.Geometry {
        withVisualizationOption(.controlPointsColor, value: color)
    }
}
