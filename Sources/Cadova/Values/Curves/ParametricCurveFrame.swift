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
