import Foundation

public extension Geometry2D {
    @UnionBuilder private func extrudedLayered(height: Double, topRadius radius: Double, layerHeight: Double) -> Geometry3D {
        let layerCount = Int(ceil(radius / layerHeight))
        let effectiveRadius = Double(layerCount) * layerHeight

        for l in 0..<layerCount {
            let z = Double(l) * layerHeight
            offset(amount: (cos(asin(z / radius) as Angle) - 1) * radius, style: .round)
                .extruded(height: height - effectiveRadius + z + layerHeight)
        }
    }

    @UnionBuilder private func extrudedConvex(height: Double, topRadius radius: Double) -> Geometry3D {
        EnvironmentReader3D { environment in
            let facetCount = environment.facets.facetCount(circleRadius: radius)

            let slices = (0...facetCount).mapUnion { f in
                let angle = (Double(f) / Double(facetCount)) * 90°
                let inset = cos(angle) * radius
                let zOffset = sin(angle) * radius
                offset(amount: inset, style: .round)
                    .extruded(height: height - radius + zOffset)
            }

            return slices.convexHull()
        }
    }

    @UnionBuilder private func extruded(height: Double, topRadius radius: Double, method: ExtrusionMethod) -> Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayered(height: height, topRadius: radius, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvex(height: height, topRadius: radius)
        }
    }

    func extruded(height: Double, radius: Double, method: ExtrusionMethod, sides: ExtrusionZSides = .top) -> Geometry3D {
        switch sides {
        case .top:
            return extruded(height: height, topRadius: radius, method: method)
        case .bottom:
            return extruded(height: height, topRadius: radius, method: method)
                .scaled(z: -1)
                .translated(z: height)
        case .both:
            return Union {
                extruded(height: height / 2, radius: radius, method: method, sides: .top)
                    .translated(z: height / 2)
                extruded(height: height / 2, radius: radius, method: method, sides: .bottom)
            }
        }
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use extruded(height:radius:method:sides:) with .layered method instead")
    func extruded(height: Double, radius: Double, layerHeight: Double, sides: ExtrusionZSides = .top) -> Geometry3D {
        extruded(height: height, radius: radius, method: .layered(height: layerHeight), sides: sides)
    }
}
