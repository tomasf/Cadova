import Foundation
import Testing
@testable import Cadova

struct EdgeShapeTests {
    private let wedgeAngles: [Angle] = [30°, 60°, 90°, 120°, 170°]

    private func faceDirection(halfAngle: Angle, positive: Bool) -> Vector2D {
        Vector2D(cos(halfAngle), positive ? sin(halfAngle) : -sin(halfAngle))
    }

    // MARK: - Chamfer

    @Test func `chamfer curve spans between the faces at the setback distance`() async throws {
        let depth = 2.5
        let shape = EdgeShape.chamfer(depth: depth)

        for wedgeAngle in wedgeAngles {
            #expect(shape.tangentSetback(wedgeAngle: wedgeAngle) == depth)

            let points = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: true, segmentCount: 10)
            try #require(points.count == 2)
            #expect(points[0].equals(faceDirection(halfAngle: wedgeAngle / 2, positive: true) * depth, within: 1e-9))
            #expect(points[1].equals(faceDirection(halfAngle: wedgeAngle / 2, positive: false) * depth, within: 1e-9))
        }
    }

    @Test func `chamfer width produces a face of the requested width at any wedge angle`() async throws {
        let width = 3.0
        let shape = EdgeShape.chamfer(width: width)

        for wedgeAngle in wedgeAngles {
            let points = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: true, segmentCount: 10)
            try #require(points.count == 2)
            #expect((points[0] - points[1]).magnitude.equals(width, within: 1e-9))

            // The curve endpoints must still lie on the face rays
            let halfAngle = wedgeAngle / 2
            let setback = shape.tangentSetback(wedgeAngle: wedgeAngle)
            #expect(points[0].equals(faceDirection(halfAngle: halfAngle, positive: true) * setback, within: 1e-9))
            #expect(points[1].equals(faceDirection(halfAngle: halfAngle, positive: false) * setback, within: 1e-9))
        }
    }

    @Test func `chamfer width and depth agree at a square edge`() async throws {
        // At 90°, width = 2·depth·sin(45°) = depth·√2
        let byDepth = EdgeShape.chamfer(depth: 2)
        let byWidth = EdgeShape.chamfer(width: 2 * 2.0.squareRoot())

        let depthPoints = byDepth.curvePoints(wedgeAngle: 90°, isConvex: true, segmentCount: 10)
        let widthPoints = byWidth.curvePoints(wedgeAngle: 90°, isConvex: true, segmentCount: 10)
        #expect(depthPoints.equals(widthPoints, within: 1e-9))
    }

    @Test func `chamfer width setback grows as the wedge sharpens`() async throws {
        let shape = EdgeShape.chamfer(width: 2)
        let sharp = shape.tangentSetback(wedgeAngle: 30°)
        let wide = shape.tangentSetback(wedgeAngle: 150°)
        #expect(sharp > wide)
    }

    // MARK: - Fillet

    @Test func `fillet setback equals radius at square edges`() async throws {
        let shape = EdgeShape.fillet(radius: 3)
        #expect(shape.tangentSetback(wedgeAngle: 90°).equals(3, within: 1e-9))
    }

    @Test func `fillet arc is tangent to both faces at any wedge angle`() async throws {
        let radius = 2.0
        let shape = EdgeShape.fillet(radius: radius)

        for wedgeAngle in wedgeAngles {
            let halfAngle = wedgeAngle / 2
            let setback = shape.tangentSetback(wedgeAngle: wedgeAngle)
            #expect(setback.equals(radius / tan(halfAngle), within: 1e-9))

            let points = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: true, segmentCount: 16)
            let first = try #require(points.first)
            let last = try #require(points.last)

            // Curve endpoints lie on the face rays at the setback distance
            #expect(first.equals(faceDirection(halfAngle: halfAngle, positive: true) * setback, within: 1e-9))
            #expect(last.equals(faceDirection(halfAngle: halfAngle, positive: false) * setback, within: 1e-9))

            // All arc points are at the fillet radius from the arc center
            let center = Vector2D(radius / sin(halfAngle), 0)
            for point in points {
                #expect((point - center).magnitude.equals(radius, within: 1e-9))
            }
        }
    }

    @Test func `fillet curve is symmetric across the bisector`() async throws {
        let points = EdgeShape.fillet(radius: 2).curvePoints(wedgeAngle: 75°, isConvex: true, segmentCount: 9)
        let mirrored = points.reversed().map { Vector2D($0.x, -$0.y) }
        #expect(points.equals(mirrored, within: 1e-9))
    }

    @Test func `fillet depth reaches the requested distance at any wedge angle`() async throws {
        let depth = 1.5
        let shape = EdgeShape.fillet(depth: depth)

        for wedgeAngle in wedgeAngles {
            let points = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: true, segmentCount: 64)
            // The deepest point of the arc (closest to the origin) must sit at exactly `depth`
            let deepest = points.min { $0.magnitude < $1.magnitude }!
            #expect(deepest.magnitude.equals(depth, within: 1e-3))
            #expect(deepest.y.equals(0, within: 1e-3))  // on the bisector
        }
    }

    @Test func `fillet depth and radius agree at a square edge`() async throws {
        // At 90°, depth = radius·(√2 − 1), the well-known corner-cut distance for a right angle
        let radius = 2.0
        let byRadius = EdgeShape.fillet(radius: radius)
        let byDepth = EdgeShape.fillet(depth: radius * (2.0.squareRoot() - 1))

        let radiusPoints = byRadius.curvePoints(wedgeAngle: 90°, isConvex: true, segmentCount: 16)
        let depthPoints = byDepth.curvePoints(wedgeAngle: 90°, isConvex: true, segmentCount: 16)
        #expect(radiusPoints.equals(depthPoints, within: 1e-9))
    }

    @Test func `fillet depth keeps reach constant while radius grows as the wedge sharpens`() async throws {
        let shape = EdgeShape.fillet(depth: 1)
        let sharpRadius = shape.filletRadius(wedgeAngle: 30°)!
        let wideRadius = shape.filletRadius(wedgeAngle: 150°)!
        #expect(sharpRadius < wideRadius)

        // Reach (depth) is identical at both angles by construction
        let sharpPoints = shape.curvePoints(wedgeAngle: 30°, isConvex: true, segmentCount: 64)
        let widePoints = shape.curvePoints(wedgeAngle: 150°, isConvex: true, segmentCount: 64)
        let sharpDepth = sharpPoints.map(\.magnitude).min()!
        let wideDepth = widePoints.map(\.magnitude).min()!
        #expect(sharpDepth.equals(wideDepth, within: 1e-3))
    }

    @Test func `curve point count follows the segment count`() async throws {
        let fillet = EdgeShape.fillet(radius: 2)
        for segmentCount in [2, 5, 32] {
            let points = fillet.curvePoints(wedgeAngle: 90°, isConvex: true, segmentCount: segmentCount)
            #expect(points.count == segmentCount + 1)
        }
        #expect(EdgeShape.fillet(radius: 2).preferredSegmentCount(wedgeAngle: 90°, segmentation: .fixed(32)) == 8)
        #expect(EdgeShape.chamfer(depth: 2).preferredSegmentCount(wedgeAngle: 90°, segmentation: .defaults) == 1)
    }

    // MARK: - Custom shapes

    @Test func `custom curve receives correct parameters`() async throws {
        let shape = EdgeShape.custom(name: "test", parameters: 1.5) { parameters in
            #expect(parameters.wedgeAngle.equals(60°, within: 1e-9))
            #expect(parameters.isConvex)
            #expect(parameters.segmentCount == 7)
            return [Vector2D(1, 1), Vector2D(1, -1)]
        }

        let points = shape.curvePoints(wedgeAngle: 60°, isConvex: true, segmentCount: 7)
        #expect(points.count == 2)
    }

    @Test func `custom setback is measured from the first curve point`() async throws {
        let shape = EdgeShape.custom(name: "test") { _ in
            [Vector2D(3, 4), Vector2D(3, -4)]
        }
        #expect(shape.tangentSetback(wedgeAngle: 90°).equals(5, within: 1e-9))
    }

    // MARK: - Identity

    @Test func `shape identity is based on kind and parameters`() async throws {
        #expect(EdgeShape.chamfer(depth: 1) == EdgeShape.chamfer(depth: 1))
        #expect(EdgeShape.chamfer(depth: 1) != EdgeShape.chamfer(depth: 2))
        #expect(EdgeShape.chamfer(depth: 1) != EdgeShape.fillet(radius: 1))
        #expect(EdgeShape.chamfer(width: 1) == EdgeShape.chamfer(width: 1))
        #expect(EdgeShape.chamfer(width: 1) != EdgeShape.chamfer(width: 2))
        #expect(EdgeShape.chamfer(width: 1) != EdgeShape.chamfer(depth: 1))
        #expect(EdgeShape.fillet(depth: 1) == EdgeShape.fillet(depth: 1))
        #expect(EdgeShape.fillet(depth: 1) != EdgeShape.fillet(depth: 2))
        #expect(EdgeShape.fillet(depth: 1) != EdgeShape.fillet(radius: 1))

        let a = EdgeShape.custom(name: "wave", parameters: 1.0) { _ in [] }
        let b = EdgeShape.custom(name: "wave", parameters: 1.0) { _ in [.zero] }
        let c = EdgeShape.custom(name: "wave", parameters: 2.0) { _ in [] }
        #expect(a == b)  // identity comes from name + parameters, not the closure
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func `shapes are codable`() async throws {
        for shape in [EdgeShape.chamfer(depth: 1), .chamfer(width: 1), .fillet(radius: 2), .fillet(depth: 1), .custom(name: "x", parameters: 3.0) { _ in [] }] {
            let data = try JSONEncoder().encode(shape)
            let decoded = try JSONDecoder().decode(EdgeShape.self, from: data)
            #expect(decoded == shape)
        }
    }
}
