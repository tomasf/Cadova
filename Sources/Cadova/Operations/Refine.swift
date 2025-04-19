import Foundation
import Manifold3D

fileprivate struct RefineCacheKey: Hashable, Sendable {
    let maxEdgeLength: Double
}

public extension Geometry3D {
    func refined(maxEdgeLength: Double) -> any Geometry3D {
        return CachingPrimitiveTransformer(body: self, key: RefineCacheKey(maxEdgeLength: maxEdgeLength)) {
            $0.refine(edgeLength: maxEdgeLength)
        }
    }
}

#warning("fix this")
/*
public extension Geometry2D {
    func refined(maxSegmentLength: Double) -> any Geometry2D {
        modifyingPolygons { polygons, e in
            return polygons.map { points in
                [points[0]] + points.paired().flatMap { from, to -> [Vector2D] in
                    let length = from.distance(to: to)
                    let segmentCount = ceil(length / maxSegmentLength)
                    guard segmentCount > 1 else { return [to] }
                    return (1...Int(segmentCount)).map { i in
                        from.point(alongLineTo: to, at: Double(i) / Double(segmentCount))
                    }
                }
            }
        }
    }
}
*/
