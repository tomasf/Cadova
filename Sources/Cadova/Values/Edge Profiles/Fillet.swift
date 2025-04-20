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
            let segmentsPerRev = environment.segmentation.segmentCount(circleRadius: max(width, height))
            let segmentCount = max(Int(ceil(Double(segmentsPerRev) / 4.0)), 1)
            let angleIncrement = 90° / Double(segmentCount)

            (0...segmentCount).mapUnion { f in
                let angle = Double(f) * angleIncrement
                let inset = (cos(angle) - 1) * width
                let zOffset = sin(angle) * height
                shape.offset(amount: inset, style: .round)
                    .extruded(height: extrusionHeight - height + zOffset)
            }.convexHull()
        }
    }
}
