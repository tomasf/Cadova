import Foundation

extension BoundingBox {
    fileprivate var visualizationBorderColor: Color {
        .blue.withAlphaComponent(0.5)
    }

    fileprivate var visualizationStandardBorderWidth: Double { 0.1 }
}

public extension BoundingBox3D {
    /// Visualizes the bounding box in 3D space with an optional scale for the border width.
    ///
    /// - Parameter scale: A multiplier for the border width, allowing customization of the visualization's thickness. Defaults to 1.0. Adjust this if the scale of the visualization is impractical.
    /// - Returns: A `Geometry3D` representation of the bounding box border.
    func visualized(scale: Double = 1.0) -> any Geometry3D {
        let borderWidth = visualizationStandardBorderWidth * scale
        let size = maximum - minimum

        func frame(_ size: Vector2D) -> any Geometry3D {
            Rectangle(size)
                .offset(amount: 0.001, style: .bevel)
                .subtracting {
                    Rectangle(size)
                        .offset(amount: -borderWidth, style: .miter)
                }
                .extruded(height: borderWidth)
        }

        let half = Union {
            frame([size.x, size.y])
            frame([size.x, size.z])
                .rotated(x: 90°)
                .translated(y: borderWidth)
            frame([size.z, size.y])
                .rotated(y: -90°)
                .translated(x: borderWidth)
        }

        return half
            .translated(minimum)
            .adding {
                half.flipped(across: .all)
                    .translated(maximum)
            }
            .colored(visualizationBorderColor)
            .background()
    }
}

public extension Geometry3D {
    /// Adds a visual representation of the bounds and bounding box for 3D geometries.
    ///
    /// - Parameter scale: A multiplier for the border width of the bounding box visualization. Defaults to 1.0. Adjust this if the scale of the visualization is impractical.
    /// - Returns: The original geometry with added visualizations for its bounds and bounding box.
    func visualizingBounds(scale: Double = 1.0) -> any Geometry3D {
        measuring { _, measurements in
            self.adding {
                measurements.boundingBox?.visualized(scale: scale)
            }
        }
    }
}
