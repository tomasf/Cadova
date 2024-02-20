import Foundation

public extension Geometry2D {
    @UnionBuilder3D private func extrudedLayered(height: Double, topRadius radius: Double, layerHeight: Double) -> any Geometry3D {
        let layerCount = Int(ceil(radius / layerHeight))
        let effectiveRadius = Double(layerCount) * layerHeight

        for l in 0..<layerCount {
            let z = Double(l) * layerHeight
            offset(amount: (cos(asin(z / radius) as Angle) - 1) * radius, style: .round)
                .extruded(height: height - effectiveRadius + z + layerHeight)
        }
    }

    @UnionBuilder3D private func extrudedConvex(height: Double, topRadius radius: Double) -> any Geometry3D {
        EnvironmentReader3D { environment in
            let facetsPerRev = environment.facets.facetCount(circleRadius: radius)
            let facetCount = max(Int(ceil(Double(facetsPerRev) / 4.0)), 1)

            let slices = (0...facetCount).mapUnion { f in
                let angle = (Double(f) / Double(facetCount)) * 90°
                let inset = cos(angle) * radius - radius
                let zOffset = sin(angle) * radius
                offset(amount: inset, style: .round)
                    .extruded(height: height - radius + zOffset)
            }

            return slices.convexHull()
        }
    }

    @UnionBuilder3D internal func filletEdgeMask(height: Double, topRadius radius: Double, method: EdgeProfile.Method) -> any Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayered(height: height, topRadius: radius, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvex(height: height, topRadius: radius)
        }
    }
}
