import Foundation

struct Rotate3D: CoreGeometry3D {
    let x: Angle
    let y: Angle
    let z: Angle
    let body: any Geometry3D

    func call(in environment: Environment) -> SCADCall {
        return SCADCall(
            name: "rotate",
            params: ["a": [x, y, z]],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        .rotation(x: x, y: y, z: z)
    }
}

public extension Geometry3D {
    /// Rotate geometry
    ///
    /// When using multiple axes, the geometry is rotated around the axes in order (first X, then Y, then Z).
    ///
    /// - Parameters:
    ///   - x: The amount to rotate around the X axis
    ///   - y: The amount to rotate around the Y axis
    ///   - z: The amount to rotate around the Z axis
    /// - Returns: A rotated geometry
    func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> any Geometry3D {
        Rotate3D(x: x, y: y, z: z, body: self)
    }

    /// Rotate around one axis
    ///
    /// - Parameters:
    ///   - angle: The angle to rotate
    ///   - axis: The axis to rotate around
    /// - Returns: A rotated geometry
    func rotated(angle: Angle, axis: Axis3D) -> any Geometry3D {
        switch axis {
        case .x: return rotated(x: angle)
        case .y: return rotated(y: angle)
        case .z: return rotated(z: angle)
        }
    }
}


struct Rotate2D: CoreGeometry2D {
    let angle: Angle
    let body: any Geometry2D

    func call(in environment: Environment) -> SCADCall {
        return SCADCall(
            name: "rotate",
            params: ["a": angle],
            body: body
        )
    }

    var bodyTransform: AffineTransform {
        .rotation(z: angle)
    }
}

public extension Geometry2D {
    /// Rotate geometry
    ///
    /// - Parameters:
    ///   - angle: The amount to rotate
    /// - Returns: A rotated geometry
    func rotated(_ angle: Angle) -> any Geometry2D {
        Rotate2D(angle: angle, body: self)
    }
}
