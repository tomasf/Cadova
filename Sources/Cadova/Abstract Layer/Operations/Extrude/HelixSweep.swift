import Foundation

public extension Geometry2D {
    /// Sweeps the 2D geometry along a helical path around the Z axis, creating a 3D spiral shape.
    ///
    /// This method sweeps the 2D shape upward while wrapping it around the Z axis:
    /// - The **X axis** of the 2D shape controls the **radial distance** from the Z axis.
    ///   To move the shape outward from the center, translate it toward **positive X**.
    /// - The **Y axis** of the 2D shape maps directly to **vertical height** along the Z axis.
    ///
    /// The shape twists around the Z axis as it rises, forming a **right-handed** helix (counter-clockwise when viewed
    /// from above). To create a **left-handed** helix instead, flip the resulting 3D geometry along the X or Y axis
    /// after extrusion.
    ///
    /// If the 2D shape is centered at the origin, parts of it will lie directly on the Z axis.
    /// To avoid this, you typically want to move the 2D shape into positive X before extrusion.
    ///
    /// - Parameters:
    ///   - pitch: The vertical distance between each complete turn of the helix. Smaller values create tighter
    ///     spirals. A value of zero or less results in empty geometry: the helix is always right-handed, so a
    ///     left-handed one is made by flipping the result rather than by giving a negative pitch.
    ///   - height: The total vertical distance the extrusion will cover along the Z axis.
    /// - Returns: A 3D geometry representing the 2D shape swept along the helical path.
    ///
    func sweptAlongHelix(pitch: Double, height: Double) -> any Geometry3D {
        // The number of turns is the height divided by the pitch, so a pitch of zero describes no helix at
        // all, and a negative one describes a left-handed helix, which this operation doesn't build. Neither
        // is worth crashing over — parametric design produces non-positive intermediate values easily — so
        // both resolve to empty geometry with a warning, the way the primitives handle degenerate sizes.
        guard pitch > 0 else {
            if pitch == 0 {
                logger.warning("""
                    A helix pitch of zero describes no turns at all. \
                    Sweeping along it results in empty geometry.
                    """)
            } else {
                logger.warning("""
                    Helix pitch must be greater than zero, but was \(pitch); this sweep only builds \
                    right-handed helices. Flip the resulting geometry along X or Y to make a left-handed one. \
                    Sweeping along a negative pitch results in empty geometry.
                    """)
            }
            return Empty()
        }

        guard height > 0 else {
            logger.warning("""
                A helix height must be greater than zero, but was \(height). \
                Sweeping along it results in empty geometry.
                """)
            return Empty()
        }

        // The profile is bent around the Z axis, so its distance from that axis becomes the helix
        // radius, and it also divides the extrusion length below. A profile lying at or left of the
        // axis has no radius to bend around, and dividing by it would put NaN into every vertex,
        // tripping `Vector`'s precondition with a message that names neither this operation nor the
        // profile that caused it.
        @Sendable func hasSweepableRadius(_ outerRadius: Double) -> Bool {
            guard outerRadius > 0 else {
                logger.warning("""
                    A helix profile must lie to the right of the Z axis, but this one reaches only \
                    x = \(outerRadius). Sweeping it along a helix results in empty geometry.
                    """)
                return false
            }
            return true
        }

        return measuringBounds { _, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let revolutions = height / pitch
            let outerRadius = bounds.maximum.x
            let lengthPerRev = outerRadius * 2 * .pi

            if hasSweepableRadius(outerRadius) {
                let helixLengthPerRev = sqrt(pow(lengthPerRev, 2) + pow(pitch, 2))
                let segmentsPerRevolution = max(
                    segmentation.segmentCount(circleRadius: outerRadius),
                    segmentation.segmentCount(length: helixLengthPerRev)
                )
                let fullRevolutions = max(Int(ceil(revolutions)), 1)
                let totalSegments = segmentsPerRevolution * fullRevolutions

                extruded(height: lengthPerRev * Double(fullRevolutions), divisions: totalSegments - 1)
                    .rotated(x: -90°)
                    .flipped(along: .z)
                    .warped(operationName: "Cadova.ExtrudeAlongHelix", cacheParameters: pitch) {
                        let turns = $0.y / lengthPerRev
                        let angle = Angle(turns: turns)
                        return Vector3D(
                            cos(angle) * $0.x,
                            sin(angle) * $0.x,
                            $0.z + turns * pitch
                        )
                    }
                    .intersecting {
                        Box(x: outerRadius * 2 + 1, y: outerRadius * 2 + 1, z: height)
                            .aligned(at: .centerXY)
                    }
                    .simplified()
            }
        }
    }
}
