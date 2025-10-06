import Foundation

public extension Geometry3D {
    /// Overlays color‑coded X (red), Y (green), and Z (blue) axes on the geometry for debugging and orientation.
    ///
    /// - The overall thickness/size of the axes is driven by the visualization scale in the environment.
    ///   Use `withVisualizationScale(_:)` on any geometry in the chain to adjust it (default: 1.0).
    /// - The arrow length is controlled by the `length` parameter.
    /// - The axes are emitted as a visual‑only part named “Visualized Axes”.
    ///
    /// See EnvironmentValues for how environment values flow through geometry.
    ///
    /// - Parameter length: The length of each axis arrow. Default is `15`.
    /// - Returns: The original geometry with visualized axes added.
    ///
    func visualizingAxes(length: Double = 15) -> any Geometry3D {
        adding { AxesVisualization(length: length) }
    }
}

fileprivate struct AxesVisualization: Shape3D {
    let length: Double
    @Environment(\.visualizationOptions) var options

    var body: any Geometry3D {
        let scale = options[.scale] as? Double ?? 1.0

        let arrow = Stack(.z) {
            Cylinder(diameter: 0.1 * scale, height: length)
            Cylinder(bottomDiameter: 0.4 * scale, topDiameter: 0, height: 0.4 * scale)
        }

        Box(0.2 * scale)
            .aligned(at: .center)
            .colored(.white)
            .adding {
                arrow.rotated(y: 90°)
                    .colored(.red)
                arrow.rotated(x: -90°)
                    .colored(.green)
                arrow
                    .colored(.blue)
            }
            .withSegmentation(count: 8)
            .inPart(named: "Visualized Axes", type: .visual)
    }
}
