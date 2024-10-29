import Foundation

internal struct RoundedBoxMaskSingleAxis: Shape3D {
    let size: Vector3D
    let cornerStyle: RoundedCornerStyle
    let axis: Axis3D
    let radii: RectangleCornerRadii

    var body: any Geometry3D {
        let rotation: Rotation3D = switch axis {
        case .z: .none
        case .x: [90°, 0°, -90°]
        case .y: [90°, 0°, 0°]
        }

        Box(size)
            .transformed(.rotation(rotation).inverse)
            .measuringBounds { box, transformedBounds in
                let transformedBounds = transformedBounds.requireNonNil()
                RoundedRectangleMask(transformedBounds.size.xy, style: cornerStyle, radii: radii)
                    .extruded(height: transformedBounds.size.z)
            }
            .rotated(rotation)
            .aligned(at: .min)
    }
}
