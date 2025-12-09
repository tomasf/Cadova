import Foundation

public extension Geometry3D {
    /// Twists the geometry around the Z axis.
    ///
    /// The X and Y coordinates of each point are rotated around the Z axis proportionally to their Z height,
    /// creating a twisting deformation effect.
    ///
    /// - Parameter amount: The total twist applied from bottom to top, expressed as an `Angle`.
    /// - Returns: A new geometry with the twist deformation applied.
    func twisted(by amount: Angle) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let height = bounds.size.z
            let radius = bounds.bounds2D.maximumDistanceToOrigin
            let totalRevolutions = amount / 360°

            let pitch = height / totalRevolutions
            let helixLength = sqrt(pow(radius * 2 * .pi, 2) + pow(pitch, 2)) * totalRevolutions

            let totalSegments = max(
                Double(segmentation.segmentCount(circleRadius: radius)) * totalRevolutions,
                Double(segmentation.segmentCount(length: helixLength))
            )
            
            geometry
                .refined(maxEdgeLength: height / totalSegments)
                .warped(operationName: "twist", cacheParameters: amount) { point in
                    let angle = amount * (point.z - bounds.minimum.z) / height
                    let cosA = cos(angle)
                    let sinA = sin(angle)
                    return Vector3D(point.x * cosA - point.y * sinA,  point.x * sinA + point.y * cosA,  point.z)
                }
                .simplified()
        }
    }
}
