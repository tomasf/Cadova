import Foundation

public extension Geometry2D {
    /// Warps the 2D geometry to follow a portion of a 2D curve.
    ///
    /// This method bends and stretches the geometry along a segment of a curve so that its local X axis
    /// follows the shape of the selected range on the curve. The geometry is scaled along the X direction to match the
    /// length of the specified segment.
    ///
    /// The Y axis of the geometry is treated as the normal direction, and each point is offset accordingly,
    /// resulting in a curved version of the original shape. This is useful for modeling banners, ribbons,
    /// or any 2D elements that must follow a curved segment.
    ///
    /// The level of detail is determined by the environment’s segmentation settings.
    ///
    /// - Parameters:
    ///   - path: The 2D curve that the geometry should follow.
    /// - Returns: A warped version of the geometry that follows the specified segment of the 2D curve.
    /// 
    func following<Path: ParametricCurve<Vector2D>>(path: Path) -> any Geometry2D {
        FollowPath2D(geometry: self, path: path)
    }
}

internal struct FollowPath2D<Path: ParametricCurve<Vector2D>>: Shape2D {
    let geometry: any Geometry2D
    let path: Path

    var body: any Geometry2D {
        @Environment(\.segmentation) var segmentation

        geometry.measuringBounds { body, bounds in
            let pathLength = path.approximateLength
            let lengthFactor = pathLength / bounds.size.x

            body.refined(maxEdgeLength: bounds.size.x / Double(segmentation.segmentCount(length: pathLength)))
                .warped(operationName: "followPath", cacheParameters: path, segmentation) {
                    path.samples(segmentation: segmentation)
                } transform: { p, frames in
                    let distanceTarget = (p.x - bounds.minimum.x) * lengthFactor
                    let (index, fraction) = frames.binarySearch(target: distanceTarget, key: \.distance)
                    let frame = if fraction > .ulpOfOne {
                        frames[index].interpolated(with: frames[index + 1], fraction: fraction)
                    } else {
                        frames[index]
                    }
                    return frame.position + frame.tangent.counterclockwiseNormal.unitVector * p.y
                }
                .simplified()
        }
    }
}
