import Foundation

struct CrossSection: Shape3D {
    let axis: Vector3D
    let offset: Double
    let content: any Geometry3D

    var body: any Geometry3D {
        let universeLength = 1000.0

        return content.intersection {
            Box([universeLength, universeLength, universeLength])
                .aligned(at: .centerXY)
                .transformed(.rotation(from: .up, to: axis))
                .translated(z: offset)
                .colored(.blue)
        }
    }
}

public extension Geometry3D {
    /// Create a cross-section of this geometry
    ///
    /// A cross-section can be a useful way to debug and verify geometry.
    ///
    /// - Parameters:
    ///   - axis: The axis along which to cut
    ///   - offset: The offset from zero at which to cut
    ///   - cuttingAway: Which direction to cut. The default, .negative, cuts away towards the negative direction of the axis, leaving the positive part visible.
    /// - Returns: A cross-sectioned geometry
    @UnionBuilder3D
    func crossSectioned(axis: Axis3D, offset: Double = 0, cuttingAway axisDirection: AxisDirection = .negative) -> any Geometry3D {
        let direction = axis.direction * (axisDirection == .positive ? -1 : 1)
        crossSectioned(axis: direction, offset: offset)
    }

    /// Create a cross-section of this geometry
    ///
    /// A cross-section can be a useful way to debug and verify geometry.
    ///
    /// - Parameters:
    ///   - axis: The axis along which to cut. The part facing this direction is visible, cutting away the rest.
    ///   - offset: The offset from zero at which to cut
    /// - Returns: A cross-sectioned geometry

    @UnionBuilder3D
    func crossSectioned(axis: Vector3D, offset: Double = 0) -> any Geometry3D {
        CrossSection(axis: axis, offset: offset, content: self)
    }
}
