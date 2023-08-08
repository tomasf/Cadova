import Foundation

public extension Geometry2D {
    @UnionBuilder3D private func extrudedLayered(height: Double, topChamferSize chamferSize: Double, layerHeight: Double) -> Geometry3D {
        let layerCount = Int(ceil(chamferSize / layerHeight))
        let effectiveChamferSize = Double(layerCount) * layerHeight

        for l in 0...layerCount {
            let z = Double(l) * layerHeight
            offset(amount: -z, style: .round)
                .extruded(height: height - effectiveChamferSize + z)
        }
    }

    @UnionBuilder3D private func extrudedConvex(height: Double, topChamferSize chamferSize: Double) -> Geometry3D {
        self
            .extruded(height: max(height - chamferSize, 0.001))
            .adding {
                self
                    .offset(amount: -chamferSize, style: .round)
                    .extruded(height: 0.001)
                    .translated(z: height - 0.001)
            }
            .convexHull()
    }

    @UnionBuilder3D private func extruded(height: Double, topChamferSize chamferSize: Double, method: ExtrusionMethod) -> Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayered(height: height, topChamferSize: chamferSize, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvex(height: height, topChamferSize: chamferSize)
        }
    }

    /// Extrudes a 2D geometry based on the given parameters.
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - chamferSize: The size of the chamfer.
    ///   - method: The extrusion method.
    ///   - sides: Specifies which sides to chamfer in the extrusion.
    /// - Returns: The extruded 3D geometry.
    func extruded(height: Double, chamferSize: Double, method: ExtrusionMethod, sides: ExtrusionZSides = .top) -> Geometry3D {
        switch sides {
        case .top:
            return extruded(height: height, topChamferSize: chamferSize, method: method)
        case .bottom:
            return extruded(height: height, topChamferSize: chamferSize, method: method)
                .scaled(z: -1)
                .translated(z: height)
        case .both:
            return extruded(height: height / 2, chamferSize: chamferSize, method: method, sides: .top)
                .translated(z: height / 2)
                .adding {
                    extruded(height: height / 2, chamferSize: chamferSize, method: method, sides: .bottom)
                }
        }
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use extruded(height:chamferSize:method:sides:) with .layered method instead")
    func extruded(height: Double, chamferSize: Double, layerHeight: Double, sides: ExtrusionZSides = .top) -> Geometry3D {
        extruded(height: height, chamferSize: chamferSize, method: .layered(height: layerHeight), sides: sides)
    }
}
