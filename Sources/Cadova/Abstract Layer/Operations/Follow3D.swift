import Foundation

public extension Geometry3D {
    /// Warps the 3D geometry to follow a path in 3D space, with controlled orientation.
    ///
    /// This method bends and stretches the geometry along a `ParametricCurve` so that its local Z axis follows
    /// the shape of the path. The geometry is stretched along its local Z axis to match the total length of
    /// the path, while the `reference` direction in the geometry is continuously reoriented to point
    /// toward the specified target at each step.
    ///
    /// The twisting behavior is smoothed and clamped using the ``EnvironmentValues/maxTwistRate`` setting.
    /// The level of detail is controlled by the environment’s segmentation settings.
    ///
    /// - Parameters:
    ///   - path: The path that the geometry should follow.
    ///   - reference: A direction in the geometry's local space that should point toward the target.
    ///   - target: The target the reference direction should point toward at each step.
    /// - Returns: A warped version of the geometry that follows the given path and orientation control.
    ///
    func following<Path: ParametricCurve<Vector3D>>(
        path: Path,
        pointing reference: Direction2D,
        toward target: ReferenceTarget
    ) -> any Geometry3D {
        FollowPath3D(geometry: self, path: path, reference: reference, target: target)
    }

    /// Warps the 3D geometry to follow a 2D path lying in the XY plane.
    ///
    /// This overload bends and stretches the geometry so that its local X axis follows the given
    /// 2D `ParametricCurve`, interpreted in the XY plane. The geometry is stretched along its local X
    /// to match the path’s total length, and is oriented consistently along the path with smoothed twist.
    ///
    /// - Parameter path: A 2D parametric curve interpreted in the XY plane that the geometry should follow.
    /// - Returns: A warped version of the geometry that follows the 2D path.
    ///
    /// - SeeAlso: ``following(path:pointing:toward:)``, ``Geometry2D/swept(along:pointing:toward:)``, ``Geometry3D/deformed(by:)``
    func following<Path: ParametricCurve<Vector2D>>(path: Path) -> any Geometry3D {
        rotated(y: -90°)
            .following(path: path.curve3D, pointing: .positiveX, toward: .direction(.negativeZ))
    }
}

// Makes the Z axis follow a path
internal struct FollowPath3D<Path: D3.Curve>: Shape3D {
    let geometry: any Geometry3D
    let path: Path
    let reference: Direction2D
    let target: ReferenceTarget

    var body: any Geometry3D {
        @Environment var environment
        @Environment(\.maxTwistRate) var maxTwistRate
        @Environment(\.segmentation) var segmentation

        if path.isEmpty {
            Empty()
        } else {
            geometry.measuringBounds { body, bounds in
                let pathLength = path.approximateLength

                body.refined(maxEdgeLength: bounds.size.z / Double(segmentation.segmentCount(length: pathLength)))
                    .warped(
                        operationName: "followPath",
                        cacheParameters: path, reference, target, segmentation, maxTwistRate
                    ) {
                        let frames = path.frames(
                            environment: environment,
                            target: target,
                            targetReference: reference,
                            perpendicularBounds: bounds.bounds2D
                        )
                        return (frames, frames.last!.distance / bounds.size.z)
                    } transform: { (p: Vector3D, result: (frames: [ParametricCurveFrame], lengthFactor: Double)) in
                        let distanceTarget = (p.z - bounds.minimum.z) * result.lengthFactor
                        let (index, fraction) = result.frames.binarySearch(target: distanceTarget, key: \.distance)

                        let transform: Transform3D = if fraction > .ulpOfOne {
                            .linearInterpolation(result.frames[index].transform, result.frames[index + 1].transform, factor: fraction)
                        } else {
                            result.frames[index].transform
                        }
                        return transform.apply(to: Vector3D(p.x, p.y, 0))
                    }
                    .simplified()
            }
        }
    }
}
