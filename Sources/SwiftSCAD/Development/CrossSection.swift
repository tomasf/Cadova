import Foundation

fileprivate struct CrossSection: Shape3D {
    let axis: Vector3D
    let offset: Double
    let content: any Geometry3D

    var body: any Geometry3D {
        let universeLength = 1000.0

        return content.intersecting {
            Box([universeLength, universeLength, universeLength])
                .aligned(at: .centerXY)
                .translated(z: offset)
                .transformed(.rotation(from: .up, to: axis))
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
    ///   - axisDirection: Which direction to cut. The default, .negative, cuts away towards the negative direction of the axis, leaving the positive part visible.
    /// - Returns: A cross-sectioned geometry
    @GeometryBuilder3D
    func crossSectioned(axis: Axis3D, offset: Double = 0, cuttingAway axisDirection: AxisDirection = .negative) -> any Geometry3D {
        let direction = axis.directionVector(axisDirection) * -1
        let signedOffset = offset * (axisDirection == .positive ? -1 : 1)
        crossSectioned(axis: direction, offset: signedOffset)
    }

    /// Create a cross-section of this geometry
    ///
    /// A cross-section can be a useful way to debug and verify geometry.
    ///
    /// - Parameters:
    ///   - axis: The axis along which to cut. The part facing this direction is visible, cutting away the rest.
    ///   - offset: The offset from zero at which to cut
    /// - Returns: A cross-sectioned geometry

    @GeometryBuilder3D
    func crossSectioned(axis: Vector3D, offset: Double = 0) -> any Geometry3D {
        CrossSection(axis: axis, offset: offset, content: self)
    }
}
