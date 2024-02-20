import Foundation

public extension Geometry2D {
    @UnionBuilder3D private func extrudedLayered(height: Double, chamferHeight: Double, chamferDepth: Double, layerHeight: Double) -> any Geometry3D {
        let layerCount = Int(ceil(chamferHeight / layerHeight))
        let effectiveChamferHeight = Double(layerCount) * layerHeight

        for l in 0...layerCount {
            let z = Double(l) * layerHeight
            let inset = Double(l) / Double(layerCount) * chamferDepth
            offset(amount: -inset, style: .round)
                .extruded(height: height - effectiveChamferHeight + z)
        }
    }

    @UnionBuilder3D private func extrudedConvex(height: Double, chamferHeight: Double, chamferDepth: Double) -> any Geometry3D {
        self
            .extruded(height: max(height - chamferHeight, 0.001))
            .adding {
                self
                    .offset(amount: -chamferDepth, style: .round)
                    .extruded(height: 0.001)
                    .translated(z: height - 0.001)
            }
            .convexHull()
    }

    @UnionBuilder3D internal func chamferEdgeMask(height: Double, chamferWidth: Double, chamferHeight: Double, method: EdgeProfile.Method) -> any Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayered(height: height, chamferHeight: chamferHeight, chamferDepth: chamferWidth, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvex(height: height, chamferHeight: chamferHeight, chamferDepth: chamferWidth)
        }
    }
}
