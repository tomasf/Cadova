import Foundation
import Manifold3D

internal struct Sweep: Shape3D {
    let shape: any Geometry2D
    let path: BezierPath3D
    let reference: Direction2D
    let target: Target

    @Environment(\.maxTwistRate) var maxTwistRate

    var body: any Geometry3D {
        shape.readingPrimitive { crossSection in
            let derivative = path.derivative
            let enableDebugging = ProcessInfo.processInfo.environment["CADOVA_SWEEP_DEBUG"] == "1"

            return path.readPositionsAndPoints { fractionsAndPoints in
                var frames: [Frame] = []
                var debugParts: [any Geometry3D]? = enableDebugging ? [] : nil

                for (t, point) in fractionsAndPoints {
                    frames.append(Frame(
                        point: point, tangent: derivative.point(at: t), reference: reference, target: target, previousSample: frames.last, debugGeometry: &debugParts
                    ))
                }

                frames.interpolateMissingAngles()
                frames.normalizeAngles()
                frames.applyTwistDamping(maxTwistRate: maxTwistRate)

                return Mesh(extruding: crossSection.polygonList(), along: frames.map(\.transform))
                    .adding(Union(debugParts ?? []))
            }
        }
        .cached(as: "sweep", geometry: shape, parameters: path, reference, target)
    }
}

extension Sweep {
    enum Target: Sendable, Hashable, Codable {
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
}

extension Sweep {
    struct Frame {
        let point: Vector3D
        let xAxis: Vector3D
        let yAxis: Vector3D
        let zAxis: Vector3D
        var angle: Angle?

        init(point: Vector3D, tangent: Vector3D, reference: Direction2D, target: Sweep.Target, previousSample: Frame?, debugGeometry: inout [any Geometry3D]?) {
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

extension [Sweep.Frame] {
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
}
