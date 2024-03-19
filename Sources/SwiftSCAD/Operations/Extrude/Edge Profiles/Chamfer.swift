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
    
    func mask(shape: any Geometry2D, extrusionHeight: Double, method: EdgeProfile.Method) -> any Geometry3D {
        switch method {
        case .layered (let layerHeight):
            layeredMask(shape: shape, extrusionHeight: extrusionHeight, layerHeight: layerHeight)
        case .convexHull:
            convexMask(shape: shape, extrusionHeight: extrusionHeight)
        }
    }

    @UnionBuilder3D
    func layeredMask(shape: any Geometry2D, extrusionHeight: Double, layerHeight: Double) -> any Geometry3D {
        let layerCount = Int(ceil(height / layerHeight))
        let effectiveChamferHeight = Double(layerCount) * layerHeight

        for l in 0...layerCount {
            let z = Double(l) * layerHeight
            let inset = Double(l) / Double(layerCount) * width
            shape.offset(amount: -inset, style: .round)
                .extruded(height: extrusionHeight - effectiveChamferHeight + z)
        }
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        shape.extruded(height: max(extrusionHeight - height, 0.001))
            .adding {
                shape
                    .offset(amount: -width, style: .round)
                    .extruded(height: 0.001)
                    .translated(z: height - 0.001)
            }
            .convexHull()
    }
}
