import Foundation

internal extension ParametricCurveFrame {
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
