import Foundation

extension RoundedBox {
    internal struct RoundedBoxSingleAxis: Shape3D {
        let size: Vector3D
        let cornerStyle: RoundedCornerStyle
        let axis: Axis3D
        let radii: RectangleCornerRadii

        var body: any Geometry3D {
            let localSize: Vector3D
            let rotation: Angle
            let rotationAxis: Axis3D

            switch axis {
            case .z:
                localSize = size
                rotation = 0°
                rotationAxis = .z
            case .x:
                localSize = [size.z, size.y, size.x]
                rotation = 90°
                rotationAxis = .y
            case .y:
                localSize = [size.x, size.z, size.y]
                rotation = -90°
                rotationAxis = .x
            }

            return RoundedRectangle(localSize.xy, style: cornerStyle, radii: radii)
                .extruded(height: localSize.z)
                .rotated(angle: rotation, axis: rotationAxis)
                .translated(z: axis == .z ? 0 : size.z)
        }
    }
}
