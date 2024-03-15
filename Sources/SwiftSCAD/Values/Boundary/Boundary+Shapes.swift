import Foundation

extension Boundary {
    static func box(_ size: V) -> Boundary {
        let cornerCount = Int(pow(2.0, Double(V.elementCount)))
        return .init(points: (0..<cornerCount).map { cornerIndex in
            V(elements: (0..<V.elementCount).map {
                Double((cornerIndex >> $0) & 0x01) * size[$0]
            })
        })
    }
}

extension Boundary2D {
    func as3D(z: Double = 0) -> Boundary3D {
        map { Vector3D($0, z: z) }
    }

    func extruded(height: Double, topScale: Vector2D = [1, 1]) -> Boundary3D {
        map {[
            Vector3D($0, z: 0),
            Vector3D($0 * topScale, z: height)
        ]}
    }

    func extruded(angle fullAngle: Angle, facets: Environment.Facets) -> Boundary3D {
        guard let maxX = max(.x) else { return .empty }
        let facetCount = facets.facetCount(circleRadius: maxX)
        let standing = as3D().transformed(.rotation(x: 90°))

        return .union((0...facetCount).map {
            let angle = (fullAngle / Double(facetCount)) * Double($0)
            return standing.transformed(.rotation(z: angle))
        })
    }

    static func circle(radius: Double, facets: Environment.Facets) -> Boundary2D {
        let facetCount = facets.facetCount(circleRadius: radius)
        let points = (0..<facetCount).map {
            let angle = (360° / Double(facetCount)) * Double($0)
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        return .init(points: points)
    }
}

extension Boundary3D {
    static func sphere(radius: Double, facets: Environment.Facets) -> Boundary3D {
        let facetCount = facets.facetCount(circleRadius: radius)
        let layers = (0..<facetCount / 2).map {
            let angle = (360° / Double(facetCount)) * Double($0)
            return Boundary2D.circle(radius: sin(angle) * radius, facets: facets)
                .as3D(z: cos(angle) * radius)
        }
        return .union(layers)
    }
}
