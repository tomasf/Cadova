import Foundation

internal struct Fillet {
    let width: Double
    let height: Double
}

extension Fillet: EdgeProfileShape {
    var shape: any Geometry2D {
        baseMask(width: width, height: height)
            .subtracting {
                Circle.ellipse(width: width * 2, height: height * 2)
                    .translated(x: width, y: height)
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
