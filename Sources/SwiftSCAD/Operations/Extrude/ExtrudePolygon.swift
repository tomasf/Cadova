import Foundation
import Collections

private extension Polyhedron {
    init(extruding shape: Polygon, along path: [AffineTransform3D], convexity: Int, environment: Environment) {
        struct Vertex: Hashable {
            let transform: Int
            let point: Int
        }

        let flatPoints = shape.points(in: environment).map { Vector3D($0) }
        let pointCount = flatPoints.count
        let sideFaces = (path.startIndex..<path.endIndex).paired().flatMap { fromPolygonIndex, toPolygonIndex in
            (0..<pointCount).map { pointIndex in
                let nextPointIndex = (pointIndex + 1) % pointCount
                return OrderedSet([
                    Vertex(transform: fromPolygonIndex, point: pointIndex),
                    Vertex(transform: toPolygonIndex, point: pointIndex),
                    Vertex(transform: toPolygonIndex, point: nextPointIndex),
                    Vertex(transform: fromPolygonIndex, point: nextPointIndex)
                ])
            }
        }

        let startFace = OrderedSet((0..<pointCount).map { Vertex(transform: 0, point: $0) })
        let endFace = OrderedSet((0..<pointCount).map { Vertex(transform: path.count - 1, point: $0) }.reversed())

        self.init(faces: sideFaces + [startFace, endFace], convexity: convexity) { ref in
            path[ref.transform].apply(to: flatPoints[ref.point])
        }
    }
}

public extension Polygon {
    /// Extrudes the polygon along a given path, creating a 3D geometry.
    ///
    /// - Parameters:
    ///   - path: An array of affine transforms representing the path along which the polygon will be extruded.
    ///   - steps: The number of steps to divide the interpolation between each pair of transforms in the `path`. Defaults to 1.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    ///
    /// - Returns: A 3D geometry resulting from extruding the polygon along the specified path.
    ///
    /// - Note: The `path` array must contain at least two transforms, and `steps` must be at least 1.
    func extruded(along path: [AffineTransform3D], steps: Int = 1, convexity: Int = 2) -> any Geometry3D {
        readEnvironment { environment in
            let expandedPath = [path[0]] + path.paired().flatMap { t1, t2 in
                (1...steps).map { .linearInterpolation(t1, t2, factor: 1.0 / Double(steps) * Double($0)) }
            }

            Polyhedron(extruding: self, along: expandedPath, convexity: convexity, environment: environment)
        }
    }

    /// Extrude the polygon along a circular helix around the Z axis
    ///
    /// - Parameters:
    ///   - pitch: The Z distance between each turn of the helix
    ///   - height: The total height of the helix
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.

    func extrudedAlongHelix(pitch: Double, height: Double, convexity: Int = 2) -> any Geometry3D {
        readEnvironment { environment in
            let radius = boundingRect(in: environment).maximum.x
            let stepsPerRev = Double(environment.facets.facetCount(circleRadius: radius))
            let steps = Int(ceil(stepsPerRev * height / pitch))

            self.extruded(along: (0..<steps).map { step in
                    .rotation(x: 90°, z: Double(step) / stepsPerRev * 360°)
                    .translated(z: Double(step) / stepsPerRev * pitch)
            }, convexity: convexity)
        }
    }
}
