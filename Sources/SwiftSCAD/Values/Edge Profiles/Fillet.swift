import Foundation

internal struct Fillet {
    let width: Double
    let height: Double
}

extension Fillet: EdgeProfileShape {
    func shape(angle: Angle) -> any Geometry2D {
        let iy = cos(angle) * height
        let inset = (height * (1 - cos(angle)) * cos(angle) / sin(angle)) + sin(angle) * width

        return Polygon([
            [0, 0],
            [inset, 0],
            [inset - sin(angle) * width, height + iy]
        ])
        .subtracting {
            Circle.ellipse(width: width * 2, height: height * 2)
                .translated(x: inset, y: height)
        }
    }

    func inset(at z: Double) -> Double {
        (sqrt(1 - pow(z / height, 2)) - 1) * -width
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        EnvironmentReader3D { environment in
            let facetsPerRev = environment.facets.facetCount(circleRadius: max(width, height))
            let facetCount = max(Int(ceil(Double(facetsPerRev) / 4.0)), 1)

            return (0...facetCount).map { f in
                let angle = (Double(f) / Double(facetCount)) * 90°
                let inset = (cos(angle) - 1) * width
                let zOffset = sin(angle) * height
                return shape.offset(amount: inset, style: .round)
                    .extruded(height: extrusionHeight - height + zOffset)
            }.convexHull()
        }
    }
}
