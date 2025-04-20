import Foundation
import Manifold3D

fileprivate struct Vertex: Hashable {
    let step: Int
    let polygonIndex: Int
    let pointIndex: Int
}

internal extension Mesh {
    init(extruding polygons: [Manifold3D.Polygon], along path: [AffineTransform3D], environment: EnvironmentValues) {
        let sideFaces = polygons.map { $0.vertices.map(Vector2D.init) }.enumerated().flatMap { polygonIndex, points in
            let pointCount = points.count
            return path.indices.paired().flatMap { fromStep, toStep in
                points.indices.map { pointIndex in Array([
                    Vertex(step: fromStep, polygonIndex: polygonIndex, pointIndex: pointIndex),
                    Vertex(step: toStep, polygonIndex: polygonIndex, pointIndex: pointIndex),
                    Vertex(step: toStep, polygonIndex: polygonIndex, pointIndex: (pointIndex + 1) % pointCount),
                    Vertex(step: fromStep, polygonIndex: polygonIndex, pointIndex: (pointIndex + 1) % pointCount)
                ].reversed())}
            }
        }

        let triangles = triangulate(polygons: polygons, epsilon: 1e-6)

        let startFaces = triangles.map {
            let v1 = polygons.vertex(index: $0.a, pathStep: 0)
            let v2 = polygons.vertex(index: $0.b, pathStep: 0)
            let v3 = polygons.vertex(index: $0.c, pathStep: 0)
            return [v3, v2, v1]
        }

        let endFaces = triangles.map {
            let v1 = polygons.vertex(index: $0.a, pathStep: path.endIndex - 1)
            let v2 = polygons.vertex(index: $0.b, pathStep: path.endIndex - 1)
            let v3 = polygons.vertex(index: $0.c, pathStep: path.endIndex - 1)
            return [v1, v2, v3]
        }
       // let startFace = indexPairs.reversed().map { Vertex(step: 0, polygonIndex: $0.polygonIndex pointIndex: $0.pointIndex) }
        //let endFace = points.indices.map { Vertex(step: path.endIndex - 1, pointIndex: $0) }

        self = Mesh(faces: sideFaces + startFaces + endFaces) {
            path[$0.step].apply(to: Vector3D(Vector2D(polygons[$0.polygonIndex].vertices[$0.pointIndex])))
        }
    }
}

fileprivate extension [Manifold3D.Polygon] {
    func vertex(index: Int, pathStep: Int) -> Vertex {
        let pair = locateIndex(index)
        return Vertex(step: pathStep, polygonIndex: pair.polygonIndex, pointIndex: pair.vertexIndex)
    }

    func locateIndex(_ index: Int) -> (polygonIndex: Int, vertexIndex: Int) {
        var offset = index
        for (polygonIndex, polygon) in enumerated() {
            if polygon.vertices.count > offset {
                return (polygonIndex, offset)
            } else {
                offset -= polygon.vertices.count
            }
        }
        preconditionFailure("Index out of range")
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
    func extruded(along path: [AffineTransform3D], steps: Int = 1) -> any Geometry3D {
        let expandedPath = [path[0]] + path.paired().flatMap { t1, t2 in
            (1...steps).map { .linearInterpolation(t1, t2, factor: 1.0 / Double(steps) * Double($0)) }
        }

        return readEnvironment { environment in
            readingPrimitive { crossSection in
                Mesh(extruding: crossSection.polygons(), along: expandedPath, environment: environment)
            }
        }
    }

    /// Extrude the 2D geometry along a circular helix around the Z axis
    ///
    /// - Parameters:
    ///  - pitch: The Z distance between each turn of the helix
    ///  - height: The total height of the helix
    ///  - offset: An optional closure calculating a varying offset
/*
    func extrudedAlongHelix(
        pitch: Double,
        height: Double,
        offset: ((Double) -> Double)? = nil
    ) -> any Geometry3D {
        measureBoundsIfNonEmpty { geometry, boundingBox in
            readEnvironment { environment in
                let radius = boundingBox.maximum.x
                let stepsPerRev = Double(environment.segmentation.segmentCount(circleRadius: radius))
                let steps = Int(ceil(stepsPerRev * height / pitch))

                let path = (0...steps).map { step -> AffineTransform3D in
                    let z = Double(step) / stepsPerRev * pitch
                    return .identity
                        .translated(x: offset?(z) ?? 0)
                        .rotated(x: 90°, z: Double(step) / stepsPerRev * 360°)
                        .translated(z: z)
                }

                self.extruded(along:path)
            }
        }

    }
 */


    func extrudedAlongHelix(radius: Double, pitch: Double, height: Double) -> any Geometry3D {
        let revolutions = height / pitch
        let lengthPerRev = radius * 2 * .pi
        let length = lengthPerRev * revolutions

        return self
            .extruded(height: length)
            .measureBoundsIfNonEmpty { geometry, environment, boundingBox in
                let outerRadius = radius + boundingBox.maximum.y
                let segmentCount = Double(environment.segmentation.segmentCount(circleRadius: outerRadius)) * revolutions
                let segmentLength = length / segmentCount

                geometry
                    .rotated(y: 90°)
                    .refined(maxEdgeLength: segmentLength)
                    .warped(operationName: "extrudeAlongHelix", cacheParameters: lengthPerRev, radius, pitch) {
                        let turns = $0.x / lengthPerRev
                        let angle = -360° * turns
                        let localRadius = radius + $0.y
                        return Vector3D(cos(angle) * localRadius, sin(angle) * localRadius, $0.z + turns * pitch)
                    }
            }
    }
}
