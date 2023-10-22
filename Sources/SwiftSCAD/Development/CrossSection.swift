import Foundation

struct CrossSection: Shape3D {
    let axis: Axis3D
    let positive: Bool
    let offset: Double
    let content: Geometry3D

    var body: Geometry3D {
        let universeLength = 1000.0
        var y: Angle = 0°
        var z: Angle = 0°

        switch axis {
        case .x: z = positive ? 0° : 180°
        case .y: z = positive ? 90° : -90°
        case .z: y = positive ? -90° : 90°
        }

        return content.subtracting {
            Box([universeLength, universeLength, universeLength], center: [.y, .z])
                .translated(x: positive ? offset : -offset)
                .rotated(y: y, z: z)
                .colored(.blue)
        }
    }
}

public extension Geometry3D {
    /// Create a cross-section of this geometry
    ///
    /// A cross-section can be a useful way to debug and verify geometry. The cut is made so that the negative part of an axis is removed, leaving the positive direction visible, or the opposite if `invert` is true.
    ///
    /// - Parameters:
    ///   - axis: The axis along which to cut
    ///   - offset: The offset from zero at which to cut
    ///   - invert: Normally, the cut is made so
    ///   - rendered: Enable cross-section in render mode
    /// - Returns: A cross-sectioned geometry
    func crossSectioned(axis: Axis3D, offset: Double = 0, invert: Bool = false, rendered: Bool = false) -> Geometry3D {
        IfPreview {
            CrossSection(axis: axis, positive: invert, offset: offset, content: self)
        } else: {
            if rendered {
                CrossSection(axis: axis, positive: invert, offset: offset, content: self)
            } else {
                self
            }
        }
    }
}
