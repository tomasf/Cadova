import Foundation

extension [ParametricCurveFrame] {
    /// Fills in frames whose reference/target alignment was momentarily degenerate, by interpolating
    /// between the resolved angles bracketing each run.
    ///
    /// The bounding angles are deliberately *not* treated as an ordered pair. They come straight from
    /// `atan2` and land anywhere in (-180°, 180°] in whatever order the curve happens to produce;
    /// `normalizeAngles()` only monotonizes them afterwards, so a run whose preceding angle is larger
    /// than its following one is entirely ordinary here.
    mutating func interpolateMissingAngles() {
        var offset = 0
        while let start = self[offset...].firstIndex(where: { $0.angle == nil }) {
            let end = self[start...].firstIndex(where: { $0.angle != nil })
            let missingIndexes = start..<(end ?? count)

            // A run at the very start of the sequence extends the following known angle backwards, and a
            // run at the very end extends the preceding one forwards. Both fall out of the shared
            // interpolation below as a zero step, since their two bounds are the same angle.
            let lowerAngle: Angle
            let upperAngle: Angle
            if start == 0 {
                lowerAngle = end.map { self[$0].angle! } ?? 0°
                upperAngle = lowerAngle
            } else {
                lowerAngle = self[start - 1].angle!
                upperAngle = end.map { self[$0].angle! } ?? lowerAngle
            }

            // The shortest signed arc, so a run spanning the ±180° seam takes the short way round rather
            // than unwinding nearly a full turn. Interpolating k interior angles between two known ones
            // divides the arc into k + 1 steps: the missing frames sit strictly between their bounds
            // rather than duplicating the preceding one and stopping short of the following one.
            let step = (upperAngle - lowerAngle).normalized / Double(missingIndexes.count + 1)
            for (position, index) in missingIndexes.enumerated() {
                self[index].angle = lowerAngle + step * Double(position + 1)
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
            // adaptive subdivision (see Loft+PolygonGroupInterpolation.interpolatePolygonGroups) also keys off
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
