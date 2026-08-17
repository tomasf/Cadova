import Foundation

public extension Geometry3D {
    /// Twists the geometry around the Z axis, spreading the twist across its full height.
    ///
    /// The X and Y coordinates of each point are rotated around the Z axis proportionally to their Z height,
    /// creating a twisting deformation effect.
    ///
    /// The span is taken from the geometry's own bounding box, so the angle you give is always the total twist
    /// from the bottom of the geometry to the top, and moving the geometry in Z doesn't change the result. Use
    /// ``twisted(by:per:)`` instead when you want a fixed rate that doesn't depend on how tall the geometry is.
    ///
    /// - Parameter amount: The total twist applied from bottom to top, expressed as an `Angle`.
    /// - Returns: A new geometry with the twist deformation applied.
    func twisted(by amount: Angle) -> any Geometry3D {
        twisting { bounds in
            let height = bounds.size.z
            guard height > 0 else { return nil }
            return (amount / height, bounds.minimum.z)
        }
    }

    /// Twists the geometry around the Z axis at a fixed rate.
    ///
    /// The X and Y coordinates of each point are rotated around the Z axis proportionally to their Z height, at a
    /// rate of `amount` per `length` units of height. Unlike ``twisted(by:)``, the rate is determined entirely by
    /// the arguments, so the same call produces the same helix on geometries of any size.
    ///
    /// ```swift
    /// bar.twisted(by: 30°, per: 10)  // 30° of twist for every 10mm of height
    /// bar.twisted(by: 3°, per: 1)    // the same rate, stated per millimeter
    /// ```
    ///
    /// The twist is zero at `z = 0`, so translating the geometry in Z rotates the result. To twist about some
    /// other plane, move it to the origin first:
    ///
    /// ```swift
    /// bar.translated(z: -20)
    ///     .twisted(by: 30°, per: 10)
    ///     .translated(z: 20)
    /// ```
    ///
    /// The geometry's bounding box is still measured, but only to decide how finely the mesh needs to be
    /// subdivided. It has no effect on the resulting shape.
    ///
    /// - Parameters:
    ///   - amount: The twist applied over each `length` of height, expressed as an `Angle`.
    ///   - length: The distance along Z over which `amount` of twist accumulates.
    /// - Returns: A new geometry with the twist deformation applied.
    func twisted(by amount: Angle, per length: Double) -> any Geometry3D {
        guard length.isFinite, length != 0 else { return self }
        return twisting { _ in (amount / length, 0) }
    }
}

fileprivate extension Geometry3D {
    /// Twists around the Z axis at the rate and reference height derived from the geometry's bounds.
    ///
    /// - Parameter parameters: Returns the twist rate per unit of Z and the Z coordinate that stays unrotated,
    ///   or `nil` to leave the geometry untouched.
    func twisting(
        _ parameters: @Sendable @escaping (BoundingBox3D) -> (rate: Angle, zeroZ: Double)?
    ) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            if let parameters = parameters(bounds), !parameters.rate.isZero {
                @Environment(\.scaledSegmentation) var segmentation
                let rate = parameters.rate
                let zeroZ = parameters.zeroZ
                let radius = bounds.bounds2D.maximumDistanceToOrigin

                // The Z distance covered by one full revolution, and the helical distance the outermost point
                // travels per unit of Z. Together these bound the edge length from both the angular and the
                // arc length side, without needing to know how tall the geometry is.
                let pitch = abs(360° / rate)
                let helixLengthPerUnitZ = sqrt(pow(radius * rate.radians, 2) + 1)

                let angularStep = pitch / Double(segmentation.segmentCount(circleRadius: radius))
                let arcStep: Double = switch segmentation {
                    case .adaptive(_, let minSize): minSize / helixLengthPerUnitZ
                    case .fixed: .infinity
                }

                geometry
                    .refined(maxEdgeLength: min(angularStep, arcStep))
                    .warped(operationName: "Cadova.Twist", cacheParameters: rate, zeroZ) { point in
                        let angle = rate * (point.z - zeroZ)
                        let cosA = cos(angle)
                        let sinA = sin(angle)
                        return Vector3D(point.x * cosA - point.y * sinA,  point.x * sinA + point.y * cosA,  point.z)
                    }
                    .simplified()
            } else {
                geometry
            }
        }
    }
}
