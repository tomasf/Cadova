import Foundation

internal struct Fillet: EdgeProfileShape {
    let width: Double
    let height: Double

    var size: Vector2D {
        .init(width, height)
    }

    var shape: any Geometry2D {
        baseMask(width: width, height: height)
            .subtracting {
                Circle.ellipse(x: width * 2, y: height * 2)
                    .aligned(at: .min)
            }
    }

    func inset(at z: Double) -> Double {
        (sqrt(1 - pow(z / height, 2)) - 1) * -width
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        readEnvironment { environment in
            let facetsPerRev = environment.facets.facetCount(circleRadius: max(width, height))
            let facetCount = max(Int(ceil(Double(facetsPerRev) / 4.0)), 1)
            let angleIncrement = 90° / Double(facetCount)

            (0...facetCount).map { f in
                let angle = Double(f) * angleIncrement
                let inset = (cos(angle) - 1) * width
                let zOffset = sin(angle) * height
                return shape.offset(amount: inset, style: .round)
                    .extruded(height: extrusionHeight - height + zOffset)
            }.convexHull()
        }
    }
}
