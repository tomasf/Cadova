import Foundation

public extension Plane {
    /// Produces a simple 3D visualization of this plane for debugging and inspection.
    ///
    /// The visualization shows:
    /// - A large, thin disk representing the plane.
    /// - A normal indicator arrow pointing along the plane's normal.
    ///
    /// Configure appearance using environment-backed modifiers:
    /// - `withVisualizationScale(_:)` controls overall size and thickness.
    /// - `withVisualizationColor(_:)` sets the color.
    ///
    /// The visualization is placed in a separate part named "Visualized Plane" with type `.visual`.
    func visualized() -> any Geometry3D {
        PlaneVisualization(plane: self)
    }
}

private struct PlaneVisualization: Shape3D {
    let plane: Plane

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .defaultPlaneColor

        Stack(.z) {
            Cylinder(radius: 100.0 * scale, height: 0.05 * scale)
            Cylinder(diameter: 0.5 * scale, height: 3 * scale)
            Cylinder(bottomDiameter: 2 * scale, topDiameter: 0, height: 2 * scale)
        }
        .colored(color)
        .rotated(from: .up, to: plane.normal)
        .translated(plane.offset)
        .inPart(.visualizedPlane)
    }
}

private extension Color {
    static let defaultPlaneColor = Color(red: 0.3, green: 0.3, blue: 0.5, alpha: 0.5)
}
