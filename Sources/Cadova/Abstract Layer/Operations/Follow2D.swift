import Foundation

public extension Geometry2D {
    /// Warps the 2D geometry to follow a 2D path.
    ///
    /// This method bends and stretches the geometry along a `BezierPath2D` so that its local X axis follows
    /// the shape of the path. The geometry is scaled along the X direction to match the length of the path.
    ///
    /// The Y axis of the geometry is treated as the normal direction, and each point is offset accordingly,
    /// resulting in a curved version of the original shape. This is useful for modeling banners, ribbons,
    /// or any 2D elements that must follow a curve.
    ///
    /// The level of detail is determined by the environment’s segmentation settings.
    ///
    /// - Parameter path: The 2D path that the geometry should follow.
    /// - Returns: A warped version of the geometry that follows the given 2D path.
    ///
    func following(path: BezierPath2D) -> any Geometry2D {
        FollowPath2D(geometry: self, path: path)
    }
}

internal struct FollowPath2D: Shape2D {
    let geometry: any Geometry2D
    let path: BezierPath2D

    @Environment(\.segmentation) var segmentation

    var body: any Geometry2D {
        geometry.measuringBounds { body, bounds in
            let frames = path.frames(in: path.positionRange, segmentation: segmentation)
            let pathLength = frames.last!.distance
            let lengthFactor = pathLength / bounds.size.x

            body
                .refined(maxEdgeLength: bounds.size.x / Double(segmentation.segmentCount(length: pathLength)))
                .warped(operationName: "followPath", cacheParameters: path, segmentation) { p in
                    let distanceTarget = (p.x - bounds.minimum.x) * lengthFactor
                    let (index, fraction) = frames.binarySearchInterpolate(target: distanceTarget, key: \.distance)
                    let frame = if fraction > .ulpOfOne {
                        frames[index].interpolated(with: frames[index + 1], fraction: fraction)
                    } else {
                        frames[index]
                    }
                    return frame.point + frame.normal.unitVector * p.y
                }
                .simplified()
        }
    }
}

fileprivate extension BezierPath2D {
    struct FollowFrame {
        let position: Position
        let point: Vector2D
        let distance: Double
        let normal: Direction2D

        func interpolated(with other: FollowFrame, fraction: Double) -> Self {
            Self(
                position: position + (other.position - position) * fraction,
                point: point.point(alongLineTo: other.point, at: fraction),
                distance: distance + (other.distance - distance) * fraction,
                normal: Direction2D(normal.unitVector + (other.normal.unitVector - normal.unitVector) * fraction)
            )
        }
    }

    func frames(in range: ClosedRange<Position>, segmentation: EnvironmentValues.Segmentation) -> [FollowFrame] {
        let derivative = self.derivative
        return pointsAtPositions(in: range, segmentation: segmentation)
            .reduce(into: []) { frames, entry in
                let distance = if let lastFrame = frames.last {
                    lastFrame.distance + (entry.point - lastFrame.point).magnitude
                } else { 0.0 }

                frames.append(FollowFrame(
                    position: entry.position,
                    point: entry.point,
                    distance: distance,
                    normal: Direction2D(derivative.point(at: entry.position)).counterclockwiseNormal
                ))
            }
    }
}
