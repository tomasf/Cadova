import Foundation

private extension Polyhedron {
    init(extruding shape: Polygon, along path: [AffineTransform3D], convexity: Int, environment: Environment) {
        struct Vertex: Hashable {
            let step: Int
            let pointIndex: Int
        }

        let points = shape.points(in: environment)
        let pointCount = points.count
        let sideFaces = path.indices.paired().flatMap { fromStep, toStep in
            points.indices.map { pointIndex in [
                Vertex(step: fromStep, pointIndex: pointIndex),
                Vertex(step: toStep, pointIndex: pointIndex),
                Vertex(step: toStep, pointIndex: (pointIndex + 1) % pointCount),
                Vertex(step: fromStep, pointIndex: (pointIndex + 1) % pointCount)
            ]}
        }

        let startFace = points.indices.map { Vertex(step: 0, pointIndex: $0) }
        let endFace = points.indices.reversed().map { Vertex(step: path.endIndex - 1, pointIndex: $0) }

        self.init(faces: sideFaces + [startFace, endFace], convexity: convexity) { vertex in
            path[vertex.step].apply(to: Vector3D(points[vertex.pointIndex]))
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

    func extrudedAlongHelix(
        pitch: Double,
        height: Double,
        convexity: Int = 2,
        offset: ((Double) -> Double)? = nil
    ) -> any Geometry3D {
        readEnvironment { environment in
            let radius = boundingRect(in: environment).maximum.x
            let stepsPerRev = Double(environment.facets.facetCount(circleRadius: radius))
            let steps = Int(ceil(stepsPerRev * height / pitch))

            let path = (0...steps).map { step -> AffineTransform3D in
                let z = Double(step) / stepsPerRev * pitch
                return .identity
                    .translated(x: offset?(z) ?? 0)
                    .rotated(x: 90°, z: Double(step) / stepsPerRev * 360°)
                    .translated(z: z)
            }

            self.extruded(along:path, convexity: convexity)
        }
    }
}
