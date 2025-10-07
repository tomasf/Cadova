import Foundation

extension ParametricCurve {
    /// Produces a simple 3D visualization of this curve for debugging and inspection.
    ///
    /// The visualization shows:
    /// - The curve as a swept tube.
    /// - Optionally, lines connecting control points.
    /// - Optionally, labeled markers at control points (when `labeledControlPoints` provides labels).
    ///
    /// Configure appearance and visibility using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall size of the tube and marker/line thickness.
    /// - `withVisualizationColor(_:)` sets the primary color of the curve.
    /// - `withVisualizationControlPoints(hidden:)` shows or hides control-point visuals.
    /// - `withVisualizationControlPoints(color:)` sets the color of control-point lines.
    /// - `withVisualizationLabels(hidden:)` shows or hides control-point labels.
    /// - `withVisualizationLabels(facing:)` orients labels.
    ///
    /// These modifiers set environment-backed options; see EnvironmentValues for how environment flows through geometry.
    ///
    /// Notes:
    /// - Labels are shown only when control points are enabled.
    ///
    public func visualized() -> any Geometry3D {
        CurveVisualization(curve: self)
    }
}

fileprivate struct CurveVisualization<Curve: ParametricCurve>: Shape3D {
    let curve: Curve

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var curveColor = .curveDefault
        @Environment(\.visualizationOptions.controlPointsColor) var controlPointColor = .controlPointDefault
        @Environment(\.visualizationOptions.controlPointsEnabled) var controlPointsEnabled = true
        @Environment(\.visualizationOptions.labelsEnabled) var labelsEnabled = true
        @Environment(\.visualizationOptions.labelDirection) var labelDirection = .labelDefault

        Circle(radius: 0.1 * scale)
            .swept(along: curve)
            .colored(curveColor)
            .adding {
                if let labeledControlPoints = curve.labeledControlPoints, controlPointsEnabled {
                    for (cp1, cp2) in labeledControlPoints.map(\.0).paired() {
                        VisualizedLine(from: cp1, to: cp2, thickness: 0.08 * scale)
                            .colored(controlPointColor)
                    }

                    if labelsEnabled {
                        for (controlPoint, label) in labeledControlPoints {
                            if let label {
                                Label(text: label)
                                    .scaled(scale)
                                    .rotated(x: 90°)
                                    .rotated(from: .back, to: labelDirection)
                                    .translated(controlPoint.vector3D)
                            }
                        }
                    }
                }
            }
            .withFontSize(1.5)
            .withTextAlignment(horizontal: .center, vertical: .center)
            .inPart(named: "Visualized Path", type: .visual)
    }

    struct VisualizedLine<V: Vector>: Shape3D {
        let from: V
        let to: V
        let thickness: Double

        var body: any Geometry3D {
            Sphere(diameter: thickness)
                .translated(from.vector3D)
                .adding {
                    Sphere(radius: thickness)
                        .translated(to.vector3D)
                }
                .convexHull()
                .withSegmentation(count: 3)
        }
    }

    struct Label: Shape3D {
        let text: String

        var body: any Geometry3D {
            Sphere(radius: 0.2)
                .colored(.black)

            Text(text).measuringBounds { text, bounds in
                Stack(.z) {
                    Capsule(bounds.size + 1)
                        .extruded(height: 0.1)
                        .colored(.white)

                    text.extruded(height: 0.01)
                        .colored(.black)
                }
                .aligned(at: .minY)
            }
        }
    }
}

fileprivate extension Color {
    static let curveDefault: Self = .blue
    static let controlPointDefault: Self = .red.with(alpha: 0.2)
}

fileprivate extension Direction3D {
    static let labelDefault: Self = .up.rotated(x: 60°, z: -30°)
}
