import Foundation

internal extension ParametricCurve<Vector3D> {
    /// Builds an exact frame at an arbitrary distance along the curve, rather than approximating it by
    /// interpolating between two nearby pre-sampled frames' transforms. `Loft` needs frames at ring
    /// positions that generally don't line up with `frames`' own sample points (its adaptive subdivision
    /// is driven by 2D shape resampling, independent of where the path itself was sampled); naively
    /// interpolating two `Transform3D`s component-wise (`Transform.linearInterpolation`) doesn't preserve
    /// orthogonality in general, which showed up as small crease artifacts. This instead re-evaluates the
    /// curve's true position and tangent at the target distance and builds a fresh frame from that,
    /// continuing from the nearest preceding sample so orientation (twist, reference/target alignment)
    /// stays consistent with the rest of the sequence.
    ///
    /// - Parameters:
    ///   - distance: The target distance, in the same arc-length units as `frames`' own `distance` field.
    ///   - frames: The curve's pre-computed frame sequence (as returned by `frames(environment:target:
    ///     targetReference:perpendicularBounds:miteringCorners:)`), used to find the nearest preceding
    ///     sample and to bracket the target distance.
    ///   - reference: The same `reference` direction passed to the original `frames(...)` call.
    ///   - target: The same `target` passed to the original `frames(...)` call.
    /// - Returns: A frame whose position and tangent are evaluated exactly at `distance`, continuing
    ///   orientation from the nearest preceding sample in `frames`.
    func exactFrame(
        atDistance distance: Double,
        in frames: [ParametricCurveFrame],
        reference: Direction2D,
        target: ReferenceTarget
    ) -> ParametricCurveFrame {
        if let first = frames.first, distance < first.distance {
            return first.continued(toDistance: distance, along: self)
        }
        if let last = frames.last, distance > last.distance {
            return last.continued(toDistance: distance, along: self)
        }

        let (lowerIndex, fraction) = frames.binarySearch(target: distance, key: \.distance)
        let lower = frames[lowerIndex]
        guard fraction > 1e-12, lowerIndex + 1 < frames.count else { return lower }
        let upper = frames[lowerIndex + 1]
        guard fraction < 1 - 1e-12 else { return upper }

        let t = lower.t + (upper.t - lower.t) * fraction
        // A curve that has collapsed at `t` reports an undefined (zero) tangent, and a frame built
        // from one has no orientation at all. Both bracketing frames are already resolved, so fall
        // back to the nearer of them, the way the `fraction` guards above do for the same reason.
        let tangent = derivativeView.tangent(at: t)
        guard !tangent.isUndefined else { return fraction < 0.5 ? lower : upper }

        let sample = CurveSample(u: t, position: point(at: t), tangent: tangent, distance: distance)
        var frame = ParametricCurveFrame(
            sample: sample, reference: reference, target: target,
            previousSample: lower.frameForContinuingPastCorner(curve: self)
        )
        // The angle in `frames` is not a raw target alignment: `frames()` resolves degenerate samples
        // array-wide (interpolateMissingAngles), unwraps the sequence so it never jumps by a turn
        // (normalizeAngles), and then damps it to the environment's `maxTwistRate`. Constructing the
        // frame above recomputes the angle from the target alone and so knows none of that, which
        // makes this function disagree with the very array it interpolates — by well over a
        // millimetre of vertex displacement wherever twist damping bit — and leaves any surface
        // built from it with a step at every stored frame. Bracketing angles are continuous and
        // already carry all of that resolution, so interpolate between them instead. (They also
        // cover the case where the reference and target are momentarily degenerate here, e.g.
        // parallel to the tangent, even though neither bracketing sample was.)
        if let lowerAngle = lower.angle, let upperAngle = upper.angle {
            frame.angle = lowerAngle + (upperAngle - lowerAngle) * fraction
        }
        // miterStretch is a compensation for the corner frame's own oblique miter slice, not a property
        // of the surrounding curve — it must not carry over to genuinely interpolated points away from the
        // corner. `Loft`'s corner handling (see Loft+PolygonGroupInterpolation.interpolatePolygonGroups) already
        // inserts the corner's own frame (with its stretch) directly at its exact distance, so any point
        // reached through this function is by construction away from the corner and needs none.
        return frame
    }

    /// - Parameter miteringCorners: When true, sharp direction changes between consecutive frames are
    ///   corrected with a mitered cross-section (reoriented to the bisector of the incoming/outgoing
    ///   directions, with a compensating stretch) so a continuous swept surface doesn't pinch at a corner.
    ///   Only meaningful for consumers that build one continuous surface across frames (e.g. `Sweep`,
    ///   `Loft`) — leave `false` for consumers that place discrete, independent copies at each frame.
    func frames(
        environment: EnvironmentValues,
        target: ReferenceTarget,
        targetReference: Direction2D,
        perpendicularBounds: BoundingBox2D?,
        miteringCorners: Bool = false
    ) -> [ParametricCurveFrame] {
        let samples = samples(segmentation: environment.segmentation)
        var frames: [ParametricCurveFrame] = []

        for sample in samples {
            frames.append(ParametricCurveFrame(sample: sample, reference: targetReference, target: target, previousSample: frames.last))
        }

        frames.interpolateMissingAngles()
        frames.normalizeAngles()
        frames.applyTwistDamping(maxTwistRate: environment.maxTwistRate)
        if miteringCorners {
            frames.miterCorners()
        }
        if let perpendicularBounds {
            frames.pruneStraightRuns(bounds: perpendicularBounds, segmentation: environment.segmentation)
        }
        return frames
    }
}
