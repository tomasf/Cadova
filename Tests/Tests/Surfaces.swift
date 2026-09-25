import Foundation
import Testing
@testable import Cadova

struct SurfaceTests {
    private static let fractions = stride(from: 0.0, through: 1.0, by: 0.125)

    // Four straight edges around the saddle whose corners are (0,0,0), (10,0,0), (10,10,10) and (0,10,0).
    // Both a ruled surface between two opposite edges and a Coons patch of all four reduce to the bilinear
    // surface z = 10uv over the 10×10 square, which encloses 100 × 10 × ¼ = 250 mm³ above z = 0.
    private static let saddleFront = BezierPath3D(linesBetween: [[0, 0, 0], [10, 0, 0]])
    private static let saddleRight = BezierPath3D(linesBetween: [[10, 0, 0], [10, 10, 10]])
    private static let saddleBack = BezierPath3D(linesBetween: [[10, 10, 10], [0, 10, 0]])
    private static let saddleLeft = BezierPath3D(linesBetween: [[0, 10, 0], [0, 0, 0]])

    // MARK: - Ruled surfaces

    @Test func `a ruled surface between two parallel lines is the flat quad between them`() {
        let surface = RuledSurface(
            from: BezierPath3D(linesBetween: [[0, 0, 0], [10, 0, 0]]),
            to: BezierPath3D(linesBetween: [[0, 10, 0], [10, 10, 0]])
        )
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(surface.point(at: [u, v]) ≈ Vector3D(10 * u, 10 * v, 0))
            }
        }
    }

    @Test func `a ruled surface matches points along its curves by length`() {
        // Halfway along this path's parameter is the corner at x = 1, but halfway along its length is x = 5.
        let unevenSegments = BezierPath3D(linesBetween: [[0, 0, 0], [1, 0, 0], [10, 0, 0]])
        let surface = RuledSurface(from: unevenSegments, to: BezierPath3D(linesBetween: [[0, 10, 0], [10, 10, 0]]))

        #expect(surface.point(at: [0.5, 0]) ≈ Vector3D(5, 0, 0))
        #expect(surface.point(at: [0.5, 1]) ≈ Vector3D(5, 10, 0))
    }

    @Test func `a ruled surface accepts 2D curves in the XY plane`() {
        let surface = RuledSurface(
            from: BezierPath2D(linesBetween: [[0, 0], [10, 0]]),
            to: BezierPath3D(linesBetween: [[0, 0, 10], [10, 0, 10]])
        )
        #expect(surface.point(at: [0.5, 0.5]) ≈ Vector3D(5, 0, 5))
    }

    @Test func `a twisted ruled surface encloses the volume under its saddle`() async throws {
        let volume = try await RuledSurface(from: Self.saddleFront, to: Self.saddleBack.reversed())
            .enclosed(against: .z(0))
            .withSegmentation(count: 32)
            .measurements.volume

        #expect(abs(volume - 250) < 0.5)
    }

    // MARK: - Coons patches

    @Test func `a Coons patch runs exactly along all four of its edges`() {
        let front = BezierPath3D(from: [0, 0, 0]) {
            curve(controlX: 20, controlY: -10, controlZ: 10, endX: 40, endY: 0, endZ: 0)
        }
        let right = BezierPath3D(from: [40, 0, 0]) {
            curve(controlX: 45, controlY: 20, controlZ: 5, endX: 40, endY: 40, endZ: 0)
        }
        let back = BezierPath3D(from: [40, 40, 0]) {
            curve(controlX: 20, controlY: 50, controlZ: 15, endX: 0, endY: 40, endZ: 0)
        }
        let left = BezierPath3D(linesBetween: [[0, 40, 0], [0, 0, 0]])
        let patch = CoonsPatch(boundary: front, right, back, left)

        let edges = [front, right, back, left].map { ArcLengthParameterization($0) }
        for t in Self.fractions {
            #expect(patch.point(at: [t, 0]) ≈ edges[0].point(atFraction: t))
            #expect(patch.point(at: [1, t]) ≈ edges[1].point(atFraction: t))
            #expect(patch.point(at: [1 - t, 1]) ≈ edges[2].point(atFraction: t))
            #expect(patch.point(at: [0, 1 - t]) ≈ edges[3].point(atFraction: t))
        }
    }

    @Test func `a Coons patch of straight edges is the bilinear surface between its corners`() async throws {
        let patch = CoonsPatch(boundary: Self.saddleFront, Self.saddleRight, Self.saddleBack, Self.saddleLeft)
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(patch.point(at: [u, v]) ≈ Vector3D(10 * u, 10 * v, 10 * u * v))
            }
        }

        let volume = try await patch
            .enclosed(against: .z(0))
            .withSegmentation(count: 32)
            .measurements.volume
        #expect(abs(volume - 250) < 0.5)
    }

    @Test func `a Coons patch bounded by a circle fills the disc`() async throws {
        // In absolute mode, an arc's angle is where it ends, measured around its center.
        let quarter = { (start: Vector2D, endAngle: Angle) in
            BezierPath2D(from: start) { counterclockwiseArc(center: [0, 0], angle: endAngle) }
        }
        let patch = CoonsPatch(
            boundary: quarter([10, 0], 90°), quarter([0, 10], 180°), quarter([-10, 0], 270°), quarter([0, -10], 360°)
        )

        let volume = try await patch
            .enclosed(offset: [0, 0, 1])
            .withSegmentation(count: 48)
            .measurements.volume
        let disc = Double.pi * 100
        #expect(abs(volume - disc) < 1)
    }

    // MARK: - Shared surface operations

    @Test func `geometry draped over a surface that mirrors XY is not inside out`() async throws {
        // Rows running along X put u along Y and v along X, a left-handed pair in XY. Mapping onto it mirrors the
        // geometry, which used to reverse every face and leave the solid inside out, with a negative volume.
        let rowsAlongX = BezierPatch(controlPoints: [
            [[0, 0, 0], [20, 0, 0], [40, 0, 0]],
            [[0, 15, 0], [20, 15, 0], [40, 15, 0]],
            [[0, 30, 0], [20, 30, 0], [40, 30, 0]],
        ])
        let rowsAlongY = BezierPatch(controlPoints: [
            [[0, 0, 0], [0, 15, 0], [0, 30, 0]],
            [[20, 0, 0], [20, 15, 0], [20, 30, 0]],
            [[40, 0, 0], [40, 15, 0], [40, 30, 0]],
        ])

        for patch in [rowsAlongX, rowsAlongY] {
            let draped = Box([10, 10, 2]).deformed(by: patch)
            let volume = try await draped.measurements.volume
            let bounds = try #require(try await draped.bounds)
            #expect(volume ≈ 2400)
            #expect(bounds ≈ BoundingBox3D(minimum: [0, 0, 0], maximum: [40, 30, 2]))
        }
    }

    @Test func `geometry can be deformed by any surface`() async throws {
        let surface = RuledSurface(
            from: BezierPath3D(linesBetween: [[0, 0, 0], [20, 0, 0]]),
            to: BezierPath3D(linesBetween: [[0, 20, 10], [20, 20, 10]])
        )
        let bounds = try #require(try await Box([20, 20, 1]).deformed(by: surface).bounds)

        #expect(bounds.minimum.z ≈ 0)
        #expect(bounds.maximum.z ≈ 11)
    }
}
