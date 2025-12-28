import Foundation

/// A ruler visualization for measuring distances in 3D space.
///
/// The ruler draws a line along the X axis with notches at regular intervals and numeric labels.
/// Use transforms to position and orient the ruler as needed.
///
/// ```swift
/// Ruler(length: 100, interval: 10)
///     .rotated(z: 90°)  // Orient along Y axis
///     .translated(x: 50)
/// ```
///
/// The thickness of the ruler elements is controlled by the visualization scale in the environment.
/// Use `withVisualizationScale(_:)` to adjust it.
///
public struct Ruler: Shape3D {
    let length: Double
    let interval: Double

    /// Creates a ruler with the specified length and interval.
    ///
    /// - Parameters:
    ///   - length: The total length of the ruler along the X axis.
    ///   - interval: The distance between notches.
    ///
    public init(length: Double, interval: Double) {
        self.length = length
        self.interval = interval
    }

    public var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .rulerDefault
        @Environment(\.visualizationOptions.labelsEnabled) var showLabels = true

        let thickness = 0.1 * scale
        let notchHeight = 0.5 * scale
        let majorNotchHeight = 1.0 * scale

        Box(x: length, y: thickness, z: thickness)
            .colored(color)
            .aligned(at: .minX)
            .adding {
                // Notches and labels
                let notchCount = Int(length / interval)
                for i in 0...notchCount {
                    let x = Double(i) * interval
                    let isMajor = i % 5 == 0
                    let height = isMajor ? majorNotchHeight : notchHeight

                    // Notch
                    Box(x: thickness, y: thickness, z: height)
                        .aligned(at: .minZ)
                        .translated(x: x)
                        .colored(color)

                    // Label at major notches
                    if isMajor && showLabels {
                        RulerLabel(value: x)
                            .scaled(scale)
                            .rotated(x: 90°)
                            .translated(x: x, z: majorNotchHeight + 0.5 * scale)
                    }
                }
            }
            .withFontSize(1.5 * scale)
            .withTextAlignment(horizontal: .center, vertical: .bottom)
            .inPart(.visualizedRuler)
    }
}

fileprivate struct RulerLabel: Shape3D {
    let value: Double

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        Text(String(format: "%g", value))
            .measuringBounds { text, bounds in
                Stack(.z, alignment: .center) {
                    Stadium(bounds.size + [1.0, 0.6] * scale)
                        .extruded(height: 0.01)
                        .colored(.white, alpha: 0.5)

                    text.extruded(height: 0.01)
                        .colored(.black)
                }
                .aligned(at: .minY)
            }
    }
}

fileprivate extension Color {
    static let rulerDefault: Self = .white
}
