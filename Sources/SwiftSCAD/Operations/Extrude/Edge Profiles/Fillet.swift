import Foundation

internal struct Fillet {
    let radius: Double
}

extension Fillet: EdgeProfileShape {
    func shape(angle: Angle) -> any Geometry2D {
        let inset = radius / tan(angle / 2)
        return Polygon([
            [0,0],
            [inset, 0],
            [cos(angle) * inset, sin(angle) * inset]
        ])
        .subtracting {
            Circle(radius: radius)
                .translated(x: inset, y: radius)
        }
    }

    var height: Double {
        radius
    }

    func inset(at z: Double) -> Double {
        (cos(asin(z / radius) as Angle) - 1) * -radius
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        EnvironmentReader3D { environment in
            let facetsPerRev = environment.facets.facetCount(circleRadius: radius)
            let facetCount = max(Int(ceil(Double(facetsPerRev) / 4.0)), 1)

            return (0...facetCount).map { f in
                let angle = (Double(f) / Double(facetCount)) * 90°
                let inset = (cos(angle) - 1) * radius
                let zOffset = sin(angle) * radius
                return shape.offset(amount: inset, style: .round)
                    .extruded(height: extrusionHeight - radius + zOffset)
            }.convexHull()
        }
    }
}
