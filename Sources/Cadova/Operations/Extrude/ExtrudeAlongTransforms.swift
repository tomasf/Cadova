import Foundation
import Manifold3D

fileprivate struct Vertex: Hashable {
    let step: Int
    let polygonIndex: Int
    let pointIndex: Int
}

internal extension Mesh {
    init(extruding polygons: [ManifoldPolygon], along path: [AffineTransform3D], environment: EnvironmentValues) {
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

        let triangles = ManifoldPolygon.triangulate(polygons, epsilon: 1e-6)

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

fileprivate extension [ManifoldPolygon] {
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

    /// Extrudes the 2D geometry along a helical path around the Z axis, creating a 3D spiral shape.
    ///
    /// This method sweeps the 2D shape upward while wrapping it around the Z axis:
    /// - The **X axis** of the 2D shape controls the **radial distance** from the Z axis.
    ///   To move the shape outward from the center, translate it toward **positive X**.
    /// - The **Y axis** of the 2D shape maps directly to **vertical height** along the Z axis.
    ///
    /// The shape twists around the Z axis as it rises, forming a **right-handed** helix (counter-clockwise when viewed from above).
    /// To create a **left-handed** helix instead, flip the resulting 3D geometry along the X or Y axis after extrusion.
    ///
    /// If the 2D shape is centered at the origin, parts of it will lie directly on the Z axis.
    /// To avoid this, you typically want to move the 2D shape into positive X before extrusion.
    ///
    /// - Parameters:
    ///   - pitch: The vertical distance between each complete turn of the helix. Smaller values create tighter spirals.
    ///   - height: The total vertical distance the extrusion will cover along the Z axis.
    /// - Returns: A 3D geometry representing the 2D shape swept along the helical path.
    ///
    func extrudedAlongHelix(pitch: Double, height: Double) -> any Geometry3D {
        measureBoundsIfNonEmpty { _, e, bounds in
            let revolutions = height / pitch
            let outerRadius = bounds.maximum.x
            let lengthPerRev = outerRadius * 2 * .pi

            let helixLength = sqrt(pow(lengthPerRev, 2) + pow(pitch, 2)) * revolutions
            let totalSegments = Int(max(
                Double(e.segmentation.segmentCount(circleRadius: outerRadius)) * revolutions,
                Double(e.segmentation.segmentCount(length: helixLength))
            ))

            extruded(height: lengthPerRev * revolutions, divisions: totalSegments)
                .rotated(x: -90°)
                .flipped(along: .z)
                .warped(operationName: "extrudeAlongHelix", cacheParameters: pitch) {
                    let turns = $0.y / lengthPerRev
                    let angle = Angle(turns: turns)
                    return Vector3D(cos(angle) * $0.x, sin(angle) * $0.x, $0.z + turns * pitch)
                }
                .simplified()
        }
    }
}
