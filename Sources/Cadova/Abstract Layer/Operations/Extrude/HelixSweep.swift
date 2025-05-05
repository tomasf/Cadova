import Foundation

public extension Geometry2D {
    /// Sweeps the 2D geometry along a helical path around the Z axis, creating a 3D spiral shape.
    ///
    /// This method sweeps the 2D shape upward while wrapping it around the Z axis:
    /// - The **X axis** of the 2D shape controls the **radial distance** from the Z axis.
    ///   To move the shape outward from the center, translate it toward **positive X**.
    /// - The **Y axis** of the 2D shape maps directly to **vertical height** along the Z axis.
    ///
    /// The shape twists around the Z axis as it rises, forming a **right-handed** helix (counter-clockwise when viewed from above).
    /// To create a **left-handed** helix instead, flip the resulting 3D geometry along the X or Y axis after extrusion.
    ///
    /// If the 2D shape is centered at the origin, parts of it will lie directly on the Z axis.
    /// To avoid this, you typically want to move the 2D shape into positive X before extrusion.
    ///
    /// - Parameters:
    ///   - pitch: The vertical distance between each complete turn of the helix. Smaller values create tighter spirals.
    ///   - height: The total vertical distance the extrusion will cover along the Z axis.
    /// - Returns: A 3D geometry representing the 2D shape swept along the helical path.
    ///
    func sweptAlongHelix(pitch: Double, height: Double) -> any Geometry3D {
        measureBoundsIfNonEmpty { _, e, bounds in
            let revolutions = height / pitch
            let outerRadius = bounds.maximum.x
            let lengthPerRev = outerRadius * 2 * .pi

            let helixLength = sqrt(pow(lengthPerRev, 2) + pow(pitch, 2)) * revolutions
            let totalSegments = Int(max(
                Double(e.segmentation.segmentCount(circleRadius: outerRadius)) * revolutions,
                Double(e.segmentation.segmentCount(length: helixLength))
            ))

            extruded(height: lengthPerRev * revolutions, divisions: totalSegments)
                .rotated(x: -90°)
                .flipped(across: .z)
                .warped(operationName: "extrudeAlongHelix", cacheParameters: pitch) {
                    let turns = $0.y / lengthPerRev
                    let angle = Angle(turns: turns)
                    return Vector3D(cos(angle) * $0.x, sin(angle) * $0.x, $0.z + turns * pitch)
                }
                .simplified()
        }
    }
}
