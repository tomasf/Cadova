import Foundation
import Manifold3D

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry.
    ///
    /// When a twist is applied (`twist != 0°`), vertical (Z) divisions are determined by the current
    /// segmentation environment (see `withSegmentation(...)`). The algorithm combines circle‑based
    /// segmentation at the shape’s maximum radius with length‑based segmentation of the helical path
    /// and uses whichever yields more divisions.
    ///
    /// Before extrusion, the 2D shape may be refined to keep the dihedral angle between adjacent
    /// helical faces at or below the environment's `twistSubdivisionThreshold`. This computes a
    /// maximum allowed base edge length from the per‑division height and twist and refines the 2D shape.
    ///
    /// A threshold of `0°` disables refinement of the 2D base. Vertical (Z) segmentation still follows
    /// `.withSegmentation(...)` and related settings. When `twist == 0°`, the threshold is ignored and
    /// no automatic base refinement is performed.
    ///
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis,
    ///     resulting in a twisted shape. Defaults to no twist.
    ///   - topScale: The final scale at the top of the extruded shape. The geometry is scaled linearly
    ///     from 1.0 at the bottom.
    ///
    func extruded(height: Double, twist: Angle = 0°, topScale: Vector2D = [1, 1]) -> any Geometry3D {
        if twist.isZero {
            extruded(height: height, twist: twist, scale: topScale, divisions: 0)
        } else {
            measuringBounds { _, bounds in
                let numRevolutions = abs(twist) / 360°
                let maxRadius = bounds.maximumDistanceToOrigin
                @Environment(\.twistSubdivisionThreshold) var maxCrease
                @Environment(\.scaledSegmentation) var segmentation

                let pitch = height / numRevolutions
                let helixLength = sqrt(pow(maxRadius * 2 * .pi, 2) + pow(pitch, 2)) * numRevolutions

                let segmentsPerRevolution = segmentation.segmentCount(circleRadius: maxRadius)
                let twistSegments = Int(Double(segmentsPerRevolution) * numRevolutions)
                let lengthSegments = segmentation.segmentCount(length: helixLength)
                let segmentCount = max(twistSegments, lengthSegments)
                let maxEdgeLength = maxEdgeLength(
                    radius: maxRadius,
                    segmentHeight: height / Double(segmentCount),
                    segmentTwist: abs(twist) / Double(segmentCount),
                    maxCrease: maxCrease
                )

                let base: any Geometry2D
                if maxEdgeLength.isFinite, maxEdgeLength > .ulpOfOne, maxEdgeLength < 2 * maxRadius {
                    base = self.refined(maxEdgeLength: maxEdgeLength)
                } else {
                    base = self
                }
                base.extruded(height: height, twist: twist, scale: topScale, divisions: segmentCount)
            }
        }
    }

    internal func extruded(height: Double, twist: Angle = 0°, scale: Vector2D = [1,1], divisions: Int) -> any Geometry3D {
        GeometryNodeTransformer(body: self) {
            .extrusion($0, type: .linear(
                height: height, twist: twist, divisions: divisions, scaleTop: scale
            ))
        }
    }

    /// Revolves a two-dimensional geometry around the Z-axis to create three-dimensional solid geometry.
    ///
    /// This operation takes the portion of the 2D shape lying on or to the right of the X=0 line (positive X-axis)
    /// and sweeps it around the Z-axis to form a solid. Any parts of the shape with negative X-coordinates
    /// are ignored during the revolution.
    ///
    /// - Parameter range: The angular range over which the geometry is revolved, specified as a `Range<Angle>`.
    ///   By default, the geometry is rotated a full circle (0°..<360°). Specifying a smaller range
    ///   creates partial revolutions, useful for generating open structures or segments.
    ///
    /// - Returns: A new 3D solid formed by revolving the original shape within the given angle range.
    ///
    /// - Example:
    /// ```swift
    /// let hemisphere = Circle(radius: 10).revolved(in: 0°..<180°)
    /// ```
    ///
    func revolved(in range: Range<Angle> = 0°..<360°) -> any Geometry3D {
        readEnvironment(\.scaledSegmentation) { segmentation in
            self.measuringBounds { geometry, bounds in
                let radius = max(bounds.maximum.x, 0)

                GeometryNodeTransformer(body: geometry) {
                    GeometryNode.extrusion($0, type: .rotational(
                        angle: range.length,
                        segments: segmentation.segmentCount(circleRadius: radius)
                    ))
                } environment: {
                    $0.applyingTransform(.rotation(x: 90°))
                }
                .rotated(z: range.lowerBound)
            }
        }
    }
}

/// Compute the minimum number of vertical subdivisions ("divisions") required
/// so that the worst-case dihedral angle between adjacent helical faces does not
/// exceed `αmax`, assuming the worst base edge span of 180°.
fileprivate func subdivisionsNeeded(radius r: Double, height h: Double, twist φ: Angle, maxCrease αmax: Angle) -> Int {
    guard αmax > 0° else { return 1 }
    // If a single segment already satisfies the crease threshold, no extra subdivision is needed.
    if dihedralAngle(radius: r, height: h, twist: φ, dTheta: 180°) <= αmax {
        return 1
    }
    var low = 1
    var high = 2
    // Exponentially search for an upper bound that satisfies the threshold.
    while dihedralAngle(radius: r, height: h / Double(high), twist: φ / Double(high), dTheta: 180°) > αmax {
        if high >= 1 << 20 { break } // Safety cap
        high *= 2
    }
    // Binary search for the minimal subdivision count in (low, high].
    while low + 1 < high {
        let mid = (low + high) / 2
        if dihedralAngle(radius: r, height: h / Double(mid), twist: φ / Double(mid), dTheta: 180°) > αmax {
            low = mid
        } else {
            high = mid
        }
    }
    return max(high, 1)
}

fileprivate func dihedralAngle(radius r: Double, height h: Double, twist φ: Angle, dTheta θ: Angle) -> Angle {
    let v0 = Vector3D(r, 0, 0)
    let v1 = Vector3D(r * cos(θ.radians), r * sin(θ.radians), 0)
    let v3 = Vector3D(r * cos(φ.radians), r * sin(φ.radians), h)
    let v2 = Vector3D(r * cos(θ.radians + φ.radians), r * sin(θ.radians + φ.radians), h)

    let e20 = v2 - v0
    let n1  = (v1 - v0) × e20
    let n2  = e20 × (v3 - v0)

    // dΘ→0 degeneracy (length→0 vector)
    if n1.squaredEuclideanNorm == 0 || n2.squaredEuclideanNorm == 0 {
        return 0°
    }

    let raw: Angle = acos((n1.normalized ⋅ n2.normalized).clamped(to: -1...1))
    return min(raw, 180° - raw)
}

fileprivate func maxEdgeLength(radius r: Double, segmentHeight h: Double, segmentTwist φ: Angle, maxCrease αmax: Angle) -> Double {
    let angleTolerance = 0.1°
    let iterations = 25

    guard αmax > 0°, dihedralAngle(radius: r, height: h, twist: φ, dTheta: 180°) > αmax else {
        return .infinity // No refinement needed; treat as unbounded edge length
    }

    var low = 0°, high = 180°

    for _ in 0..<iterations {
        let mid = 0.5 * (low + high)
        if dihedralAngle(radius: r, height: h, twist: φ, dTheta: mid) <= αmax {
            low = mid
        } else {
            high = mid
        }
        if high - low < angleTolerance { break }
    }

    let length = 2 * r * sin(low * 0.5)
    return max(length, .leastNonzeroMagnitude) // Avoid zero which would disable refinement
}
