import Foundation

public extension Geometry2D {
    func extrudedHull(height: Double, to topShape: Geometry2D) -> Geometry3D {
        let sliceHeight = 0.001

        return extruded(height: sliceHeight)
            .adding {
                topShape
                    .extruded(height: sliceHeight)
                    .translated(z: height - sliceHeight)
            }
            .convexHull()
    }

    func extrudedHull(height: Double, @UnionBuilder to topShape: () -> Geometry2D) -> Geometry3D {
        extrudedHull(height: height, to: topShape())
    }
}
