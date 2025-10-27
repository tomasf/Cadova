import Foundation
import Manifold3D

internal struct SweepVertex: Hashable, Codable {
    let stepIndex: Int
    let polygonIndex: Int
    let pointIndex: Int
}

internal extension Mesh<SweepVertex>  {
    // Sweep the polygons along the path of transforms
    init(extruding polygons: SimplePolygonList, along transforms: [Transform3D], cacheName: String, cacheParameters: any CacheKey...) {
        precondition(transforms.count >= 2, "A sweep needs at least two transforms")

        let faceTriangles = polygons.triangulated()
        let isClosed = transforms.last!.isApproximatelyEqual(to: transforms.first!)
        let closedLastPolygon = isClosed ? transforms.count - 1 : -1

        let sideFaces = transforms.enumerated().dropFirst().flatMap { step, transform in
            let thisStepIndex = step == closedLastPolygon ? 0 : step
            let previousStepIndex = step - 1
            return polygons.polygons.enumerated().flatMap { polygonIndex, polygon in
                polygon.vertices.indices.wrappedPairs().flatMap { pointIndex1, pointIndex2 in [
                    [
                        SweepVertex(stepIndex: previousStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                        SweepVertex(stepIndex: thisStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                        SweepVertex(stepIndex: thisStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                    ],[
                        SweepVertex(stepIndex: thisStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                        SweepVertex(stepIndex: previousStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                        SweepVertex(stepIndex: previousStepIndex, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                    ]
                ]}
            }
        }

        var startFace: [[SweepVertex]] = []
        var endFace: [[SweepVertex]] = []

        if isClosed == false {
            for triangle in faceTriangles {
                let (polygon1, point1) = triangle.0
                let (polygon2, point2) = triangle.1
                let (polygon3, point3) = triangle.2

                startFace.append([
                    SweepVertex(stepIndex: 0, polygonIndex: polygon3, pointIndex: point3),
                    SweepVertex(stepIndex: 0, polygonIndex: polygon2, pointIndex: point2),
                    SweepVertex(stepIndex: 0, polygonIndex: polygon1, pointIndex: point1),
                ])
                endFace.append([
                    SweepVertex(stepIndex: transforms.count - 1, polygonIndex: polygon1, pointIndex: point1),
                    SweepVertex(stepIndex: transforms.count - 1, polygonIndex: polygon2, pointIndex: point2),
                    SweepVertex(stepIndex: transforms.count - 1, polygonIndex: polygon3, pointIndex: point3),
                ])
            }
        }

        self.init(
            faces: sideFaces + startFace + endFace,
            name: "ExtrudeAlongTransforms:" + cacheName,
            cacheParameters: cacheParameters
        ) { vertex in
            let point = polygons[vertex.polygonIndex][vertex.pointIndex]
            return transforms[vertex.stepIndex].apply(to: Vector3D(point))
        }
    }
}


public extension Geometry2D {
    /// Extrudes a 2D shape along a given path, creating a 3D geometry.
    ///
    /// - Parameters:
    ///   - path: An array of affine transforms representing the path along which the shape will be extruded.
    ///   - steps: The number of steps to divide the interpolation between each pair of transforms in the `path`.
    ///     Defaults to 1.
    ///
    /// - Returns: A 3D geometry resulting from extruding the shape along the specified path.
    ///
    /// - Note: The `path` array must contain at least two transforms, and `steps` must be at least 1.
    func extruded(along path: [Transform3D], steps: Int = 1) -> any Geometry3D {
        let expandedPath = [path[0]] + path.paired().flatMap { t1, t2 in
            (1...steps).map { .linearInterpolation(t1, t2, factor: 1.0 / Double(steps) * Double($0)) }
        }

        return readEnvironment { environment in
            readingConcrete { crossSection in
                let polygons = crossSection.polygonList()
                return Mesh(
                    extruding: crossSection.polygonList(),
                    along: expandedPath,
                    cacheName: "ExtrudeAlongTransforms",
                    cacheParameters: path, steps, polygons
                )
            }
        }
    }
}
