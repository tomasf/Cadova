import Foundation

internal protocol EdgeProfileShape {
    func mask(shape: any Geometry2D, extrusionHeight: Double, method: EdgeProfile.Method) -> any Geometry3D
    func shape(angle: Angle) -> any Geometry2D
}

internal extension EdgeProfile {
    var profileShape: any EdgeProfileShape {
        switch self {
        case .sharp: 
            SharpEdge()
        case .fillet(let radius):
            Fillet(radius: radius)
        case .chamfer(let width, let height):
            Chamfer(width: width, height: height)
        }
    }
}

internal struct SharpEdge: EdgeProfileShape {
    func mask(shape: any Geometry2D, extrusionHeight: Double, method: EdgeProfile.Method) -> any Geometry3D {
        shape.extruded(height: extrusionHeight)
    }

    func shape(angle: Angle) -> any Geometry2D {
        Rectangle(.zero)
    }
}
