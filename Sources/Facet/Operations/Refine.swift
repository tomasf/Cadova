import Foundation
import Manifold

public extension Geometry3D {
    func refining(maxEdgeLength: Double) -> any Geometry3D {
        modifyingPrimitive { mesh, _ in
            mesh.refine(edgeLength: maxEdgeLength)
        }
    }
}

public extension Geometry2D {
    func refining(maxSegmentLength: Double) -> any Geometry2D {
        modifyingPrimitive { cs, e in
            let polygons = cs.polygons().map { $0.map(Vector2D.init) }

            let newPolygons = polygons.map { points in
                [points[0]] + points.paired().flatMap { from, to -> [Vector2D] in
                    let length = from.distance(to: to)
                    let segmentCount = ceil(length / maxSegmentLength)
                    guard segmentCount > 1 else { return [to] }
                    return (1...Int(segmentCount)).map { i in
                        from.point(alongLineTo: to, at: Double(i) / Double(segmentCount))
                    }
                }
            }

            return CrossSection.polygons(newPolygons, fillRule: .evenOdd)
        }
    }
}
