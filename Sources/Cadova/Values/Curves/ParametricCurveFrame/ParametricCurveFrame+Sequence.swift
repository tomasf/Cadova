import Foundation

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
