import Foundation

internal extension BezierPath3D {
    func frames(
        environment: EnvironmentValues,
        target: FrameTarget,
        targetReference: Direction2D,
        perpendicularBounds: BoundingBox2D,
        enableDebugging: Bool = false
    ) -> ([Frame], [any Geometry3D]) {
        let derivative = self.derivative
        let fractionsAndPoints = self.pointsAtPositions(segmentation: environment.segmentation)
        var frames: [Frame] = []
        var debugParts: [any Geometry3D]? = enableDebugging ? [] : nil

        var distance = 0.0
        var lastPoint: Vector3D?
        for (t, point) in fractionsAndPoints {
            if let last = lastPoint {
                distance += (point - last).magnitude
            }
            frames.append(Frame(
                t: t,
                distance: distance,
                point: point,
                tangent: derivative.point(at: t),
                reference: targetReference,
                target: target,
                previousSample: frames.last,
                debugGeometry: &debugParts
            ))
            lastPoint = point
        }

        frames.interpolateMissingAngles()
        frames.normalizeAngles()
        frames.applyTwistDamping(maxTwistRate: environment.maxTwistRate)
        frames.pruneStraightRuns(bounds: perpendicularBounds, segmentation: environment.segmentation)
        return (frames, debugParts ?? [])
    }

    enum FrameTarget: Sendable, Hashable, Codable {
        case point (Vector3D)
        case line (D3.Line)
        case direction (Direction3D)

        func targetPoint(from plane: Plane) -> Vector3D {
            switch self {
            case let .point(p): p
            case let .line(line): plane.intersection(with: line) ?? line.closestPoint(to: plane.offset)
            case let .direction(dir): plane.offset + dir.unitVector
            }
        }
    }

    struct Frame {
        let t: Double
        let distance: Double
        let point: Vector3D
        let xAxis: Vector3D
        let yAxis: Vector3D
        let zAxis: Vector3D
        var angle: Angle?

        init(t: Double, distance: Double, point: Vector3D, tangent: Vector3D, reference: Direction2D, target: FrameTarget, previousSample: Frame?, debugGeometry: inout [any Geometry3D]?) {
            self.t = t
            self.distance = distance
            zAxis = tangent.normalized
            self.point = point
            let plane = Plane(offset: point, normal: Direction3D(zAxis))

            if let previousSample {
                let rotation = Transform3D.rotation(from: Direction3D(previousSample.zAxis), to: Direction3D(zAxis))
                xAxis = rotation.apply(to: previousSample.xAxis).normalized
                yAxis = rotation.apply(to: previousSample.yAxis).normalized
            } else {
                let provisionalX = (Swift.abs(zAxis.x) < 0.9) ? Vector3D(x: 1) : Vector3D(y: 1)
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

            debugGeometry?.append(contentsOf: [
                Box(x: 0.1, y: 0.1, z: 10)
                    .rotated(from: .up, to: .init(referenceVector))
                    .translated(point)
                    .colored(.blue)
                    .inPart(named: "referenceVector", type: .visual),

                Box(x: 0.1, y: 0.1, z: 10)
                    .rotated(from: .up, to: .init(targetDirection))
                    .translated(point)
                    .colored(.green)
                    .inPart(named: "targetDirection", type: .visual),

                Box(1)
                    .aligned(at: .center)
                    .translated(globalTargetPoint)
                    .colored(.purple)
                    .inPart(named: "globalTargetPoint", type: .visual)
            ])
        }

        var transform: Transform3D {
            let alignedX = Direction3D(xAxis).rotated(angle: angle!, around: Direction3D(zAxis))
            let alignedY = Direction3D(zAxis × alignedX.unitVector)
            return Transform3D(orthonormalBasisOrigin: point, x: alignedX, y: alignedY, z: Direction3D(zAxis))
        }
    }
}

extension [BezierPath3D.Frame] {
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

    mutating func pruneStraightRuns(bounds: BoundingBox2D, segmentation: EnvironmentValues.Segmentation) {
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
