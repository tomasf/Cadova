import Foundation

internal struct Chamfer {
    let width: Double
    let height: Double
}

extension Chamfer: EdgeProfileShape {
    func shape(angle: Angle) -> any Geometry2D {
        let length = height / sin(angle)
        return Polygon([
            [0, 0],
            [width, 0],
            [cos(angle) * length, sin(angle) * length],
        ])
    }

    func inset(at z: Double) -> Double {
        (z / height) * width
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        shape.extruded(height: max(extrusionHeight - height, 0.01))
            .adding {
                shape
                    .offset(amount: -width, style: .round)
                    .extruded(height: 0.01)
                    .translated(z: extrusionHeight - 0.01)
            }
            .convexHull()
    }
}
