import Foundation

public extension Geometry3D {
    /// Adds visual representations of the 3D coordinate axes to the geometry for debugging and visualization purposes.
    ///
    /// This method overlays the geometry with color-coded arrows that represent the X, Y, and Z axes.
    /// Each axis arrow is shown with a default length and is scaled based on the specified `scale`.
    /// The X-axis is represented in red, the Y-axis in green, and the Z-axis in blue.
    ///
    /// This feature is intended to assist in understanding the orientation and scaling of local coordinate systems
    /// during development.
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
                .withSegmentation(count: 8)
                .background()
        }
    }
}
