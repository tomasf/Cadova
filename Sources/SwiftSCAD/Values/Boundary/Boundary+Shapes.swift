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

    func extruded(height: Double, twist: Angle, topScale: Vector2D, facets: EnvironmentValues.Facets) -> Boundary3D {
        let hasTwist = abs(twist) > .radians(.ulpOfOne)
        let twistSlices = hasTwist ? extrusionSlices(height: height, twist: twist, scale: topScale, facets: facets) : 1

        let points = (0...twistSlices).flatMap { slice in
            let f = Double(slice) / Double(twistSlices)
            let transform = AffineTransform3D.identity
                .translated(z: height * f)
                .scaled(.init([1, 1] + (topScale - [1, 1]) * f, z: 1))
                .rotated(z: f * twist)

            return self.points.map { transform.apply(to: Vector3D($0, z: 0)) }
        }
        return .points(points)
    }

    func extrusionSlices(height: Double, twist: Angle, scale: Vector2D, facets: EnvironmentValues.Facets) -> Int {

        func helixArcLength(maxSquaredDistance: Double) -> Double {
            let c = height / abs(twist).radians
            return abs(twist).radians * sqrt(maxSquaredDistance + c * c)
        }

        func helixSlices(maxSquaredDistance: Double, minLength: Double, minAngle: Angle) -> Int {
            let absTwist = abs(twist)
            let minSlices = Swift.max(Int(ceil(absTwist / 120°)), 1);
            let angleSlices = Int(ceil(absTwist / minAngle))
            let lengthSlices = Int(ceil(helixArcLength(maxSquaredDistance: maxSquaredDistance) / minLength))
            return Swift.max(minSlices, Swift.min(angleSlices, lengthSlices))
        }

        func diagonalSlices(deltaSquaredDistance: Double, minLength: Double) -> Int {
            Swift.max(Int(ceil(sqrt(deltaSquaredDistance + height * height) / minLength)), 1)
        }

        switch facets {
        case .fixed (let count):
            return Int(Swift.max(twist / 360°, 1)) * count

        case .dynamic (let minAngle, let minLength):
            let deltaSquaredDistance = points.map { ($0 - $0 * scale).squaredEuclideanNorm }.max()
            let maxSquaredBaseDistance = points.map(\.squaredEuclideanNorm).max()

            guard let deltaSquaredDistance, let maxSquaredBaseDistance else { return 1 }

            let diagonalSlices = diagonalSlices(deltaSquaredDistance: deltaSquaredDistance, minLength: minLength)
            let helixSlices = helixSlices(maxSquaredDistance: maxSquaredBaseDistance, minLength: minLength, minAngle: minAngle)

            return Swift.max(diagonalSlices, helixSlices)
        }
    }

    func extruded(angle fullAngle: Angle, facets: EnvironmentValues.Facets) -> Boundary3D {
        guard let minX = min(.x), let maxX = max(.x) else { return .empty }
        let radius = Swift.max(maxX, -minX)
        let facetCount = facets.facetCount(circleRadius: radius)
        let standing = as3D().transformed(.rotation(x: 90°))

        return .union((0...facetCount).map {
            let angle = (fullAngle / Double(facetCount)) * Double($0)
            return standing.transformed(.rotation(z: angle))
        })
    }

    static func circle(radius: Double, facets: EnvironmentValues.Facets) -> Boundary2D {
        let facetCount = facets.facetCount(circleRadius: radius)
        let points = (0..<facetCount).map {
            let angle = (360° / Double(facetCount)) * Double($0)
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        return .init(points: points)
    }
}

extension Boundary3D {
    static func sphere(radius: Double, facets: EnvironmentValues.Facets) -> Boundary3D {
        let facetCount = facets.facetCount(circleRadius: radius)
        let layers = (0..<facetCount / 2).map {
            let angle = (360° / Double(facetCount)) * Double($0)
            return Boundary2D.circle(radius: sin(angle) * radius, facets: facets)
                .as3D(z: cos(angle) * radius)
        }
        return .union(layers)
    }
}
