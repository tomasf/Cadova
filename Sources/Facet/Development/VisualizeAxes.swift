import Foundation

public extension Geometry3D {
    /// Adds visual representations of the 3D coordinate axes to the geometry for debugging and visualization purposes.
    ///
    /// This method overlays the geometry with color-coded arrows that represent the X, Y, and Z axes.
    /// Each axis arrow is shown with a default length and is scaled based on the specified `scale`.
    /// The X-axis is represented in red, the Y-axis in green, and the Z-axis in blue.
    ///
    /// This feature is intended to assist in understanding the orientation and scaling of the geometry during development.
    ///
    /// - Parameters:
    ///   - scale: A scaling factor applied to the axes visualizations. Default is `1`.
    ///   - length: The length of each axis arrow. Default is `10`.
    /// - Returns: A new `Geometry3D` object that includes the original geometry with visualized axes.
    func visualizingAxes(scale: Double = 1, length: Double = 10) -> any Geometry3D {
        let arrow = Cylinder(diameter: 0.1, height: length)
            .adding {
                Cylinder(bottomDiameter: 0.2, topDiameter: 0, height: 0.2)
                    .translated(z: length)
            }

        return self.adding {
            Box(0.2)
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
                .scaled(scale)
                .usingFacets(count: 8)
                .background()
        }
    }
}

public extension Geometry2D {
    /// Adds visual representations of the 2D coordinate axes to the geometry for debugging and visualization purposes.
    ///
    /// This method overlays the geometry with color-coded arrows that represent the X and Y axes.
    /// Each axis arrow is shown with a default length and is scaled based on the specified `scale`.
    /// The X-axis is represented in red and the Y-axis in green.
    ///
    /// This feature is intended to assist in understanding the orientation and scaling of the geometry during development.
    ///
    /// - Parameters:
    ///   - scale: A scaling factor applied to the axes visualizations. Default is `1`.
    ///   - length: The length of each axis arrow. Default is `10`.
    /// - Returns: A new `Geometry2D` object that includes the original geometry with visualized axes.
    func visualizingAxes(scale: Double = 1, length: Double = 10) -> any Geometry2D {
        let arrow = Rectangle([length - 0.1, 0.1])
            .aligned(at: .centerY)
            .translated(x: 0.1)
            .adding {
                Polygon([[0, 0.1], [0.2, 0], [0, -0.1]])
                    .translated(x: length)
            }

        return self.adding {
            Rectangle(0.2)
                .aligned(at: .center)
                .colored(.white)
                .adding {
                    arrow
                        .colored(.red)
                    arrow.rotated(90°)
                        .colored(.green)
                }
                .scaled(scale)
                .background()
        }
    }
}
