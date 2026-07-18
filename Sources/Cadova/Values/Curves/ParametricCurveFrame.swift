import Foundation

public enum ReferenceTarget: Sendable, Hashable, Codable {
    case point (Vector3D)
    case line (D3.Line)
    case direction (Direction3D)
}

internal extension ReferenceTarget {
    func targetPoint(from plane: Plane) -> Vector3D {
        switch self {
        case let .point(p): p
        case let .line(line): plane.intersection(with: line) ?? line.closestPoint(to: plane.offset)
        case let .direction(dir): plane.offset + dir.unitVector
        }
    }
}

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
        let sample = CurveSample(u: t, position: point(at: t), tangent: derivativeView.tangent(at: t), distance: distance)
        var frame = ParametricCurveFrame(
            sample: sample, reference: reference, target: target,
            previousSample: lower.frameForContinuingPastCorner(curve: self)
        )
        // Reference/target can be momentarily degenerate (e.g. parallel to the tangent) exactly at this
        // point even though neither bracketing sample was; `frames()` resolves this array-wide via
        // interpolateMissingAngles(), which isn't available here, so fall back to interpolating between
        // the two (already-resolved) bracketing angles instead of leaving it unset.
        if frame.angle == nil, let lowerAngle = lower.angle, let upperAngle = upper.angle {
            frame.angle = lowerAngle + (upperAngle - lowerAngle) * fraction
        }
        // miterStretch is a compensation for the corner frame's own oblique miter slice, not a property
        // of the surrounding curve — it must not carry over to genuinely interpolated points away from the
        // corner. `Loft`'s corner handling (see Loft+PolygonGroups.interpolatePolygonGroups) already
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

struct ParametricCurveFrame {
    let t: Double
    let distance: Double
    let point: Vector3D
    var xAxis: Vector3D
    var yAxis: Vector3D
    var zAxis: Vector3D
    var angle: Angle?
    /// Set by `miterCorners()` for frames at a sharp direction change: a direction (within the
    /// cross-sectional plane) and factor to stretch the cross-section by, compensating for the oblique
    /// miter slice so a swept surface maintains constant width through the corner instead of pinching.
    var miterStretch: (direction: Vector3D, factor: Double)?

    init(
        t: Double,
        distance: Double,
        point: Vector3D,
        xAxis: Vector3D,
        yAxis: Vector3D,
        zAxis: Vector3D,
        angle: Angle?,
        miterStretch: (direction: Vector3D, factor: Double)?
    ) {
        self.t = t
        self.distance = distance
        self.point = point
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.zAxis = zAxis
        self.angle = angle
        self.miterStretch = miterStretch
    }

    func interpolated(to other: Self, factor rawFactor: Double, distance: Double, point: Vector3D, t: Double) -> Self {
        let factor = rawFactor.clamped(to: 0...1)
        let rotation = Transform3D.partialRotation(from: zAxis, to: other.zAxis, factor: factor)
        let interpolatedAngle: Angle?
        if let angle, let otherAngle = other.angle {
            interpolatedAngle = angle + (otherAngle - angle).normalized * factor
        } else {
            interpolatedAngle = angle ?? other.angle
        }

        return Self(
            t: t,
            distance: distance,
            point: point,
            xAxis: rotation.apply(to: xAxis).normalized,
            yAxis: rotation.apply(to: yAxis).normalized,
            zAxis: rotation.apply(to: zAxis).normalized,
            angle: interpolatedAngle,
            miterStretch: miterStretch.interpolated(to: other.miterStretch, factor: factor)
        )
    }

    init(sample: CurveSample<Vector3D>, reference: Direction2D, target: ReferenceTarget, previousSample: Self?) {
        self.t = sample.u
        self.distance = sample.distance
        zAxis = sample.tangent.unitVector
        self.point = sample.position
        let plane = Plane(offset: point, normal: Direction3D(zAxis))

        if let previousSample {
            let rotation = Transform3D.rotation(from: Direction3D(previousSample.zAxis), to: Direction3D(zAxis))
            xAxis = rotation.apply(to: previousSample.xAxis).normalized
            yAxis = rotation.apply(to: previousSample.yAxis).normalized
        } else {
            let provisionalX = (abs(zAxis.x) < 0.9) ? Vector3D(x: 1) : Vector3D(y: 1)
            yAxis = (zAxis × provisionalX).normalized
            xAxis = (yAxis × zAxis).normalized
        }

        let referenceVector = (reference.x * xAxis + reference.y * yAxis).normalized
        let globalTargetPoint = target.targetPoint(from: plane)
        let targetDirection = (globalTargetPoint - point).normalized

        let projectedReference = referenceVector - zAxis * (referenceVector ⋅ zAxis)
        let projectedTarget = targetDirection - zAxis * (targetDirection ⋅ zAxis)

        let referenceLength = projectedReference.squaredEuclideanNorm
        let targetLength = projectedTarget.squaredEuclideanNorm

        let epsilon = 1e-10
        if referenceLength > epsilon, targetLength > epsilon {
            let referenceInPlane = projectedReference.normalized
            let targetInPlane = projectedTarget.normalized

            let sinTheta = (referenceInPlane × targetInPlane) ⋅ zAxis
            let cosTheta = referenceInPlane ⋅ targetInPlane
            angle = atan2(sinTheta, cosTheta)
        } else {
            angle = nil
        }
    }

    var transform: Transform3D {
        let alignedX = Direction3D(xAxis).rotated(angle: angle!, around: Direction3D(zAxis))
        let alignedY = Direction3D(zAxis × alignedX.unitVector)
        let base = Transform3D(orthonormalBasisOrigin: point, x: alignedX, y: alignedY, z: Direction3D(zAxis))
        guard let miterStretch else { return base }

        // Scale, in local cross-section space, along the local direction miterStretch.direction projects
        // to. Applied before `base` so the stretch happens in the cross-section's own coordinate system,
        // prior to being placed/rotated into world space.
        let localX = miterStretch.direction ⋅ alignedX.unitVector
        let localY = miterStretch.direction ⋅ alignedY.unitVector
        let factor = miterStretch.factor
        let localScale = Transform3D.identity.mapValues { row, column, value in
            switch (row, column) {
            case (0, 0): value + (factor - 1) * localX * localX
            case (0, 1): value + (factor - 1) * localX * localY
            case (1, 0): value + (factor - 1) * localY * localX
            case (1, 1): value + (factor - 1) * localY * localY
            default: value
            }
        }
        return localScale.concatenated(with: base)
    }
}

private extension ParametricCurveFrame {
    func continued(toDistance distance: Double, along curve: any ParametricCurve<Vector3D>) -> Self {
        let base = frameForContinuingPastCorner(curve: curve)
        let offset = base.zAxis * (distance - base.distance)
        return Self(
            t: base.t,
            distance: distance,
            point: base.point + offset,
            xAxis: base.xAxis,
            yAxis: base.yAxis,
            zAxis: base.zAxis,
            angle: base.angle,
            miterStretch: nil
        )
    }

    func frameForContinuingPastCorner(curve: any ParametricCurve<Vector3D>) -> Self {
        guard miterStretch != nil else { return self }

        var frame = self
        let tangent = curve.derivativeView.tangent(at: t).unitVector
        let rotation = Transform3D.rotation(from: Direction3D(zAxis), to: Direction3D(tangent))
        frame.xAxis = rotation.apply(to: xAxis).normalized
        frame.yAxis = rotation.apply(to: yAxis).normalized
        frame.zAxis = tangent
        frame.miterStretch = nil
        return frame
    }
}

private extension Optional where Wrapped == (direction: Vector3D, factor: Double) {
    func interpolated(to other: Self, factor: Double) -> Self {
        switch (self, other) {
        case (.none, .none):
            return nil
        case (.some(let stretch), .none):
            return miterStretch(direction: stretch.direction, factor: 1 + (stretch.factor - 1) * (1 - factor))
        case (.none, .some(let stretch)):
            return miterStretch(direction: stretch.direction, factor: 1 + (stretch.factor - 1) * factor)
        case (.some(let stretch), .some(let otherStretch)):
            return (
                direction: (stretch.direction * (1 - factor) + otherStretch.direction * factor).normalized,
                factor: stretch.factor + (otherStretch.factor - stretch.factor) * factor
            )
        }
    }

    private func miterStretch(direction: Vector3D, factor: Double) -> Self {
        guard abs(factor - 1) > 1e-12 else { return nil }
        return (direction: direction, factor: factor)
    }
}

private extension Transform3D {
    static func partialRotation(from: Vector3D, to: Vector3D, factor: Double) -> Transform3D {
        let from = from.normalized
        let to = to.normalized
        let dot = (from ⋅ to).clamped(to: -1...1)
        let cross = from × to

        if cross.magnitude < 1e-12 {
            if dot > 0 { return .identity }
            let perpendicular = abs(from.x) < 0.9
                ? from × Vector3D(1, 0, 0)
                : from × Vector3D(0, 1, 0)
            return .rotation(angle: 180° * factor, around: Direction3D(perpendicular))
        }

        return .rotation(angle: acos(dot) * factor, around: Direction3D(cross))
    }
}


extension [ParametricCurveFrame] {
    mutating func interpolateMissingAngles() {
        var offset = 0
        while let start = self[offset...].firstIndex(where: { $0.angle == nil }) {
            let end = self[start...].firstIndex(where: { $0.angle != nil })

            let resolvedIndexes = start..<(end ?? count)
            let resolvedRange: Range<Angle>

            if start == 0 {
                let value = end.map { self[$0].angle! } ?? 0°
                resolvedRange = value..<value
            } else {
                resolvedRange = (self[start - 1].angle!)..<(self[end ?? start - 1].angle!)
            }

            let step = resolvedRange.length / Double(resolvedIndexes.length)
            for i in resolvedIndexes {
                self[i].angle = resolvedRange.lowerBound + Double(i - resolvedIndexes.lowerBound) * step
            }

            if let end {
                offset = end
            } else {
                break
            }
        }
    }

    mutating func normalizeAngles() {
        guard !isEmpty else { return }
        for i in indices.dropFirst() {
            let previous = self[i-1].angle!
            self[i].angle = previous + (self[i].angle! - previous).normalized
        }
    }

    mutating func applyTwistDamping(maxTwistRate: Angle) {
        for i in indices.dropFirst() {
            let current = self[i - 1].angle!
            let delta = self[i].angle! - current
            let distance = (self[i].point - self[i - 1].point).magnitude
            let maxDelta = maxTwistRate * distance
            self[i].angle = current + delta.clamped(to: (-maxDelta...maxDelta))
        }
    }

    // Reorients interior frames at a direction change to the bisector of the incoming/outgoing travel
    // direction (a miter join, as used for corners in path stroking / pipe elbows), with a compensating
    // stretch so a continuous swept surface keeps constant width through the corner instead of pinching.
    // Position (not the curve's own analytic tangent) drives this, so it degrades gracefully: for a
    // smoothly-sampled curve, neighboring points are nearly collinear and the correction is negligible;
    // at a genuine sharp corner, it's the correct volume-preserving miter.
    mutating func miterCorners() {
        guard count > 2 else { return }

        for i in 1..<(count - 1) {
            let incoming = self[i].point - self[i - 1].point
            let outgoing = self[i + 1].point - self[i].point
            guard incoming.magnitude > 1e-9, outgoing.magnitude > 1e-9 else { continue }

            let inDirection = incoming.normalized
            let outDirection = outgoing.normalized

            let bisectorSum = inDirection + outDirection
            guard bisectorSum.magnitude > 1e-6 else { continue } // near-180° reversal; miter is undefined

            let newZAxis = bisectorSum.normalized
            let cosHalfAngle = (newZAxis ⋅ inDirection).clamped(to: -1...1)
            guard cosHalfAngle > 0.05 else { continue } // avoid runaway stretch near an extreme reversal
            // Below this, treat it as ordinary curve sampling noise rather than a real corner: on a
            // smoothly-sampled curve, adjacent frames differ by a tiny fraction of a degree and this
            // would otherwise fire on nearly every frame, not just genuine direction changes. Loft's
            // adaptive subdivision (see Loft+PolygonGroups.interpolatePolygonGroups) also keys off
            // `miterStretch` being set only at real corners to know where to split cleanly.
            guard cosHalfAngle < 0.999 else { continue }

            let bendVector = outDirection - inDirection
            let projectedBend = bendVector - newZAxis * (bendVector ⋅ newZAxis)
            guard projectedBend.magnitude > 1e-9 else { continue } // already straight; nothing to correct

            // Nudge the existing (already twist-resolved) basis from the old tangent to the new miter
            // normal via the shortest rotation, rather than re-deriving it from scratch, so whatever
            // reference/target alignment was already established is preserved.
            let rotation = Transform3D.rotation(from: Direction3D(self[i].zAxis), to: Direction3D(newZAxis))
            let newXAxis = rotation.apply(to: self[i].xAxis).normalized
            let newYAxis = rotation.apply(to: self[i].yAxis).normalized

            self[i].zAxis = newZAxis
            self[i].xAxis = newXAxis
            self[i].yAxis = newYAxis
            self[i].miterStretch = (direction: projectedBend.normalized, factor: 1 / cosHalfAngle)
        }
    }

    mutating func pruneStraightRuns(bounds: BoundingBox2D, segmentation: Segmentation) {
        // Only prune for adaptive segmentation. Fixed already has the desired number of frames.
        guard !isEmpty, case .adaptive (let angleTolerance, let distanceTolerance) = segmentation else { return }

        let maxRadius = bounds.maximumDistanceToOrigin
        let cosTolerance = cos(angleTolerance)

        var lastSolidFrame = self[0]
        var i = 1
        while i < count - 1 {
            let frame = self[i]
            let directionDifference = lastSolidFrame.zAxis.normalized ⋅ frame.zAxis.normalized
            let twistDifference = lastSolidFrame.angle!.distance(to: frame.angle!)

            let centerDistance = (frame.point - lastSolidFrame.point).magnitude
            let twistDistance = (twistDifference / 360°) * maxRadius * 2 * .pi

            if (directionDifference > cosTolerance && twistDifference < angleTolerance) || (centerDistance < distanceTolerance && twistDistance < distanceTolerance) {
                remove(at: i)
            } else {
                lastSolidFrame = frame
                i += 1
            }
        }
    }
}
