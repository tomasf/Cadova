import Foundation

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
