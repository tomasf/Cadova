import Foundation
import Manifold3D

fileprivate struct Vertex: Hashable {
    let stepIndex: Int
    let polygonIndex: Int
    let pointIndex: Int
}

internal extension Mesh {
    // Sweep the polygons along the path of transforms
    init(extruding polygons: SimplePolygonList, along transforms: [Transform3D]) {
        let faceTriangles = polygons.triangulate()

        let sideFaces = transforms.enumerated().dropFirst().flatMap { step, transform in
            polygons.polygons.enumerated().flatMap { polygonIndex, polygon in
                polygon.vertices.indices.wrappedPairs().flatMap { pointIndex1, pointIndex2 in [
                    [
                        Vertex(stepIndex: step-1, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                        Vertex(stepIndex: step, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                        Vertex(stepIndex: step, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                    ],[
                        Vertex(stepIndex: step, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                        Vertex(stepIndex: step-1, polygonIndex: polygonIndex, pointIndex: pointIndex1),
                        Vertex(stepIndex: step-1, polygonIndex: polygonIndex, pointIndex: pointIndex2),
                    ]
                ]}
            }
        }

        var startFace: [[Vertex]] = []
        var endFace: [[Vertex]] = []

        for triangle in faceTriangles {
            let (polygon1, point1) = triangle.0
            let (polygon2, point2) = triangle.1
            let (polygon3, point3) = triangle.2

            startFace.append([
                Vertex(stepIndex: 0, polygonIndex: polygon3, pointIndex: point3),
                Vertex(stepIndex: 0, polygonIndex: polygon2, pointIndex: point2),
                Vertex(stepIndex: 0, polygonIndex: polygon1, pointIndex: point1),
            ])
            endFace.append([
                Vertex(stepIndex: transforms.count - 1, polygonIndex: polygon1, pointIndex: point1),
                Vertex(stepIndex: transforms.count - 1, polygonIndex: polygon2, pointIndex: point2),
                Vertex(stepIndex: transforms.count - 1, polygonIndex: polygon3, pointIndex: point3),
            ])
        }

        self = Mesh(faces: sideFaces + startFace + endFace) { vertex in
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
    ///   - steps: The number of steps to divide the interpolation between each pair of transforms in the `path`. Defaults to 1.
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
                Mesh(extruding: crossSection.polygonList(), along: expandedPath)
            }
        }
    }
}
