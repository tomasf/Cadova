import Foundation

public extension BoundingBox3D {
    /// Renders this box as a thin 3D frame for debugging.
    ///
    /// - Thickness is driven by the visualization scale in the environment.
    ///   Use `withVisualizationScale(_:)` to adjust (default: 1.0).
    /// - Color uses the visualization primary color.
    ///   Use `withVisualizationColor(_:)` to override.
    /// - Emitted as a visual-only part named “Visualized Bounding Box”.
    ///
    /// See EnvironmentValues for how environment values flow through geometry.
    func visualized() -> any Geometry3D {
        BoundingBoxVisualization(box: self)
    }
}

public extension Geometry3D {
    /// Overlays the geometry's bounding box as a thin 3D frame for debugging.
    ///
    /// This is useful for visualizing the region affected by range-based spatial APIs
    /// like ``within(x:y:z:)`` or ``EdgeCriteria/within(x:y:z:)``.
    ///
    /// ```swift
    /// // Visualize the entire bounding box
    /// geometry.visualizingBounds()
    ///
    /// // Visualize a portion of the bounding box
    /// box.cuttingEdgeProfile(.fillet(radius: 2), along: .sharp().within(z: 0...))
    ///    .visualizingBounds(z: 0...)  // Shows the region where edges are selected
    /// ```
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, uses the geometry's full x extent.
    ///   - y: Optional range along the y-axis. If `nil`, uses the geometry's full y extent.
    ///   - z: Optional range along the z-axis. If `nil`, uses the geometry's full z extent.
    ///
    /// - Thickness is driven by the visualization scale in the environment
    ///   (`withVisualizationScale(_:)`).
    /// - Color uses the visualization primary color (`withVisualizationColor(_:)`).
    /// - Adds a visual-only part named "Visualized Bounding Box".
    ///
    func visualizingBounds(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            geometry
            BoundingBoxVisualization(box: bounds.within(x: x, y: y, z: z, margin: 0))
        }
    }
}

fileprivate struct BoundingBoxVisualization: Shape3D {
    let box: BoundingBox3D

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var borderColor = .borderColorDefault

        let borderWidth = 0.1 * scale
        let size = box.maximum - box.minimum

        let half = Union {
            frame([size.x, size.y], borderWidth: borderWidth)
            frame([size.x, size.z], borderWidth: borderWidth)
                .rotated(x: 90°)
                .translated(y: borderWidth)
            frame([size.z, size.y], borderWidth: borderWidth)
                .rotated(y: -90°)
                .translated(x: borderWidth)
        }

        half
            .translated(box.minimum)
            .adding {
                half.flipped(along: .all)
                    .translated(box.maximum)
            }
            .colored(borderColor)
            .inPart(.visualizedBoundingBox)
    }

    func frame(_ size: Vector2D, borderWidth: Double) -> any Geometry3D {
        Rectangle(size)
            .offset(amount: 0.001, style: .bevel)
            .subtracting {
                Rectangle(size)
                    .offset(amount: -borderWidth, style: .miter)
            }
            .extruded(height: borderWidth)
    }
}

fileprivate extension Color {
    static let borderColorDefault: Color = .blue.with(alpha: 0.7)
}
