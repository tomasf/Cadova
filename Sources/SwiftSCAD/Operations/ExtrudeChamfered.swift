import Foundation

public extension Geometry2D {
    @UnionBuilder3D private func extrudedLayeredTopChamfer(height: Double, chamferHeight: Double, chamferDepth: Double, layerHeight: Double) -> Geometry3D {
        let layerCount = Int(ceil(chamferHeight / layerHeight))
        let effectiveChamferHeight = Double(layerCount) * layerHeight

        for l in 0...layerCount {
            let z = Double(l) * layerHeight
            let inset = Double(l) / Double(layerCount) * chamferDepth
            offset(amount: -inset, style: .round)
                .extruded(height: height - effectiveChamferHeight + z)
        }
    }

    @UnionBuilder3D private func extrudedConvexTopChamfer(height: Double, chamferHeight: Double, chamferDepth: Double) -> Geometry3D {
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

    @UnionBuilder3D private func extrudedTopChamfer(height: Double, chamferHeight: Double, chamferDepth: Double, method: ExtrusionMethod) -> Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayeredTopChamfer(height: height, chamferHeight: chamferHeight, chamferDepth: chamferDepth, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvexTopChamfer(height: height, chamferHeight: chamferHeight, chamferDepth: chamferDepth)
        }
    }

    /// Extrudes a 2D geometry with a chamfer based on the given parameters.
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - chamferHeight: The size of the chamfer in the Z axis.
    ///   - chamferDepth: The size of the chamfer in the X and Y axes.
    ///   - method: The extrusion method.
    ///   - sides: Specifies which sides to chamfer in the extrusion.
    /// - Returns: The extruded 3D geometry.
    func extruded(height: Double, chamferHeight: Double, chamferDepth: Double, method: ExtrusionMethod, sides: ExtrusionZSides = .top) -> Geometry3D {
        switch sides {
        case .top:
            return extrudedTopChamfer(height: height, chamferHeight: chamferHeight, chamferDepth: chamferDepth, method: method)
        case .bottom:
            return extrudedTopChamfer(height: height, chamferHeight: chamferHeight, chamferDepth: chamferDepth, method: method)
                .scaled(z: -1)
                .translated(z: height)
        case .both:
            return extruded(height: height / 2, chamferHeight: chamferHeight, chamferDepth: chamferDepth, method: method, sides: .top)
                .translated(z: height / 2)
                .adding {
                    extruded(height: height / 2, chamferHeight: chamferHeight, chamferDepth: chamferDepth, method: method, sides: .bottom)
                }
        }
    }

    /// Extrudes a 2D geometry with a chamfer based on the given parameters.
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - chamferSize: The size of the chamfer.
    ///   - method: The extrusion method.
    ///   - sides: Specifies which sides to chamfer in the extrusion.
    /// - Returns: The extruded 3D geometry.
    func extruded(height: Double, chamferSize: Double, method: ExtrusionMethod, sides: ExtrusionZSides = .top) -> Geometry3D {
        extruded(height: height, chamferHeight: chamferSize, chamferDepth: chamferSize, method: method, sides: sides)
    }
}
