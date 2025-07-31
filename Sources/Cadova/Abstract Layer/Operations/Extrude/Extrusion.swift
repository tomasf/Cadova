import Foundation
import Manifold3D

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a
    ///     twisted shape. Defaults to no twist.
    ///   - topScale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the
    ///     bottom.
    ///
    func extruded(height: Double, twist: Angle = 0°, topScale: Vector2D = [1, 1]) -> any Geometry3D {
        if twist.isZero {
            extruded(height: height, twist: twist, scale: topScale, divisions: 0)
        } else {
            measureBoundsIfNonEmpty { _, e, bounds in
                let numRevolutions = abs(twist) / 360°
                let maxRadius = bounds.maximumDistanceToOrigin

                let pitch = height / numRevolutions
                let helixLength = sqrt(pow(maxRadius * 2 * .pi, 2) + pow(pitch, 2)) * numRevolutions
                let maxCrease = 15°

                let segmentsPerRevolution = e.segmentation.segmentCount(circleRadius: maxRadius)
                let twistSegments = Int(Double(segmentsPerRevolution) * numRevolutions)
                let lengthSegments = e.segmentation.segmentCount(length: helixLength)
                let segmentCount = max(twistSegments, lengthSegments)
                var maxEdgeLength = maxEdgeLength(
                    radius: maxRadius,
                    segmentHeight: height / Double(segmentCount),
                    segmentTwist: abs(twist) / Double(segmentCount),
                    maxCrease: maxCrease
                )

                let base: any Geometry2D
                if maxEdgeLength < maxRadius, maxEdgeLength > 0 {
                    switch e.segmentation {
                    case .fixed (let count):
                        maxEdgeLength = max(maxRadius / Double(count), maxEdgeLength)
                    case .adaptive (let angle, let length):
                        maxEdgeLength = max(length, maxEdgeLength)
                    }
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
        readEnvironment(\.segmentation) { segmentation in
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

    guard dihedralAngle(radius: r, height: h, twist: φ, dTheta: 180°) > αmax else {
        return r * 2
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

    return 2 * r * sin(low * 0.5)
}
