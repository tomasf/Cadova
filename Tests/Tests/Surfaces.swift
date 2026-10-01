import Foundation
import Testing
import Manifold3D
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

    // MARK: - Spline surfaces

    // Quarter circle of radius 10 as an exact rational quadratic arc.
    private static let arcWeight = sqrt(2) / 2

    @Test func `a spline surface with Bezier knots and unit weights is the Bezier patch of its control points`() {
        let grid: [[Vector3D]] = [
            [[0, 0, 0], [1, 0, 0.8], [2, 0, -0.2], [3, 0, 0]],
            [[0, 1, 0.5], [1, 1, 1.5], [2, 1, 0.3], [3, 1, -0.4]],
            [[0, 2, 0.4], [1, 2, 1.2], [2, 2, 1], [3, 2, 0.2]],
            [[0, 3, 0], [1, 3, 0.4], [2, 3, 0.1], [3, 3, 1.2]],
        ]
        let spline = SplineSurface.uniformCubic(controlPoints: grid)
        let patch = BezierPatch(controlPoints: grid)
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(spline.point(at: [u, v]) ≈ patch.point(at: [u, v]))
            }
        }
    }

    @Test func `a rational spline surface describes an exact quarter cylinder`() {
        let w = Self.arcWeight
        let cylinder = SplineSurface(
            uDegree: 2, vDegree: 1,
            uKnots: [0, 0, 0, 1, 1, 1], vKnots: [0, 0, 1, 1],
            controlPoints: [
                [([10, 0, 0], weight: 1), ([10, 0, 20], weight: 1)],
                [([10, 10, 0], weight: w), ([10, 10, 20], weight: w)],
                [([0, 10, 0], weight: 1), ([0, 10, 20], weight: 1)],
            ]
        )
        for u in Self.fractions {
            for v in Self.fractions {
                let point = cylinder.point(at: [u, v])
                #expect(Vector2D(point.x, point.y).magnitude ≈ 10)
                let expectedHeight = 20 * v
                #expect(point.z ≈ expectedHeight)
            }
        }
    }

    @Test func `a rational spline surface describes an exact sphere octant`() {
        // The tensor product of two quarter-circle arcs: a meridian from the equator to the pole, swept a quarter
        // turn around Z. Its weights are products of the arcs' weights, so any division before the end would pull
        // the surface off the sphere wherever those differ.
        let w = Self.arcWeight
        let meridian: [(radius: Double, z: Double, weight: Double)] = [(10, 0, 1), (10, 10, w), (0, 10, 1)]
        let sweep: [(x: Double, y: Double, weight: Double)] = [(1, 0, 1), (1, 1, w), (0, 1, 1)]
        let octant = SplineSurface(
            uDegree: 2, vDegree: 2,
            uKnots: [0, 0, 0, 1, 1, 1], vKnots: [0, 0, 0, 1, 1, 1],
            controlPoints: meridian.map { m in
                sweep.map { s in (Vector3D(m.radius * s.x, m.radius * s.y, m.z), weight: m.weight * s.weight) }
            }
        )
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(octant.point(at: [u, v]).magnitude ≈ 10)
            }
        }
    }

    // MARK: - Interpolating surfaces

    private static let heightGrid: [[Vector3D]] = [
        [0, 2, 3, 1],
        [1, 6, 8, 2],
        [2, 7, 5, 3],
        [0, 3, 2, 1],
    ].enumerated().map { row, heights in
        heights.enumerated().map { column, z in Vector3D(Double(column) * 10, Double(row) * 10, Double(z)) }
    }

    @Test func `an interpolating surface passes through every point of its grid at whole-number parameters`() {
        let surface = InterpolatingSurface(through: Self.heightGrid)
        #expect(surface.uDomain == 0...3)
        #expect(surface.vDomain == 0...3)
        for (row, points) in Self.heightGrid.enumerated() {
            for (column, point) in points.enumerated() {
                #expect(surface.point(at: [Double(row), Double(column)]) ≈ point)
            }
        }
    }

    @Test func `an interpolating surface through a regular flat grid is that plane`() {
        let grid = (0..<4).map { row in (0..<5).map { column in Vector3D(Double(column) * 10, Double(row) * 5, 0) } }
        let surface = InterpolatingSurface(through: grid)
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(surface.point(atFraction: [u, v]) ≈ Vector3D(40 * v, 15 * u, 0))
            }
        }
    }

    @Test func `an interpolating surface whose edge rows touch at one point stays open`() {
        // The first and last rows meet at their middle point only. Deciding closure per evaluated point would
        // turn the curve across the rows into a loop at exactly that column, leaving a seam in the surface.
        let grid: [[Vector3D]] = [
            [[0, 0, 0], [10, 10, 0], [20, 0, 0]],
            [[0, 5, 5], [10, 12, 5], [20, 5, 5]],
            [[0, 20, 0], [10, 10, 0], [20, 20, 0]],
        ]
        let surface = InterpolatingSurface(through: grid)
        let atSharedColumn = surface.point(at: [0.5, 1])
        let besideIt = surface.point(at: [0.5, 1 + 2e-4])
        #expect(atSharedColumn.distance(to: besideIt) < 0.01)
    }

    @Test func `enclosing a surface with a long edge against a plane`() async throws {
        // The face on the plane runs along every edge of the surface's grid, about 4000 points here. It used to be
        // flattened for triangulation from its first three points, which lie on a straight edge, collapsing it onto
        // a line, and triangulating that ran out of stack long before it got through all of them.
        let strip = BezierPatch(controlPoints: [
            [[0, 0, 5], [0, 1, 5]],
            [[200, 0, 5], [200, 1, 5]],
        ])
        let enclosed = strip.enclosed(against: .z(0)).withSegmentation(.adaptive(minAngle: 2°, minSize: 0.1))
        let volume = try await enclosed.measurements.volume
        #expect(volume ≈ 1000)
    }

    // MARK: - Shared surface operations

    // A flat 40 × 30 mm patch with its rows along Y, so u runs along X and v along Y, given a domain matching its size:
    // draping over it leaves geometry exactly where it is.
    private static let flatPatch = BezierPatch(controlPoints: [
        [[0, 0, 0], [0, 30, 0]],
        [[40, 0, 0], [40, 30, 0]],
    ]).remapped(u: 0...40, v: 0...30)

    @Test func `draping uses the geometry's X and Y directly as the surface's u and v`() async throws {
        // Unlike stretching a footprint over the whole surface, a small piece stays small and where it was placed.
        let piece = Box([10, 5, 2]).translated(x: 12, y: 20)
        let bounds = try #require(try await piece.draped(over: Self.flatPatch).withSegmentation(count: 8).bounds)
        #expect(bounds ≈ BoundingBox3D(minimum: [12, 20, 0], maximum: [22, 25, 2]))
    }

    @Test func `draping carries geometry past the surface's edges`() async throws {
        // Past the edges of a flat surface, its tangent planes are the same plane, so an overhanging box keeps its size.
        let overhanging = Box([60, 50, 2]).translated(x: -10, y: -10)
        let bounds = try #require(try await overhanging.draped(over: Self.flatPatch).withSegmentation(count: 8).bounds)
        #expect(bounds ≈ BoundingBox3D(minimum: [-10, -10, 0], maximum: [50, 40, 2]))
    }

    // A surface of your own that, like many would, has no answer outside its domain.
    private struct DomainOnlySurface: ParametricSurface {
        var uDomain: ClosedRange<Double> { 0...40 }
        var vDomain: ClosedRange<Double> { 0...30 }

        func point(at uv: Vector2D) -> Vector3D {
            guard uDomain.contains(uv.x), vDomain.contains(uv.y) else { return Vector3D(.nan) }
            return Vector3D(uv.x, uv.y, uv.x * 0.25)
        }
    }

    @Test func `draping extends a surface of your own past its domain`() async throws {
        let overhanging = Box([60, 10, 2]).translated(x: -10)
        let bounds = try #require(try await overhanging.draped(over: DomainOnlySurface()).withSegmentation(count: 8).bounds)
        #expect(bounds ≈ BoundingBox3D(minimum: [-10, 0, -2.5], maximum: [50, 10, 14.5]))

        let remapped = try #require(try await Box([60, 10, 2]).translated(x: -30)
            .draped(over: DomainOnlySurface().remapped(u: -20...20, v: 0...30)).withSegmentation(count: 8).bounds)
        #expect(remapped ≈ BoundingBox3D(minimum: [-10, 0, -2.5], maximum: [50, 10, 14.5]))
    }

    // A quadratic patch curving up along u, with rows along Y.
    private static let curvedPatch = BezierPatch(controlPoints: [
        [[0, 0, 0], [0, 10, 0]],
        [[5, 0, 0], [5, 10, 4]],
        [[10, 0, 6], [10, 10, 6]],
    ])

    @Test func `a surface continues past an edge along its slope across that edge`() {
        // The slope across the u = 1 edge of a quadratic is twice the step from the middle row to the last.
        for v in [0.0, 0.3, 1.0] {
            let edge = Self.curvedPatch.point(at: [1, v])
            let middle = Vector3D(5, 10 * v, 4 * v)
            let slope = (Vector3D(10, 10 * v, 6) - middle) * 2
            let expected = edge + slope * 0.5
            #expect(Self.curvedPatch.point(at: [1.5, v]) ≈ expected)
        }
        // At u = 0, the slope across the edge points the other way, toward negative u.
        let start = Self.curvedPatch.point(at: [0, 0.5])
        let slope = (Vector3D(5, 5, 2) - Vector3D(0, 5, 0)) * 2
        let expected = start - slope * 0.25
        #expect(Self.curvedPatch.point(at: [-0.25, 0.5]) ≈ expected)
    }

    @Test func `a surface continues past a corner as the tangent plane there`() {
        let corner = Self.curvedPatch.point(at: [1, 1])
        let uSlope = (Vector3D(10, 10, 6) - Vector3D(5, 10, 4)) * 2
        let vSlope = Vector3D(10, 10, 6) - Vector3D(10, 0, 6)
        let expected = corner + uSlope * 0.2 + vSlope * 0.3
        #expect(Self.curvedPatch.point(at: [1.2, 1.3]) ≈ expected)
    }

    @Test func `a surface meets its extension without a gap or a crease`() {
        let surface = CoonsPatch(
            boundary: BezierPath3D(from: [0, 0, 0]) { curve(controlX: 20, controlY: -10, controlZ: 10, endX: 40, endY: 0, endZ: 0) },
            BezierPath3D(from: [40, 0, 0]) { curve(controlX: 45, controlY: 20, controlZ: 5, endX: 40, endY: 40, endZ: 0) },
            BezierPath3D(from: [40, 40, 0]) { curve(controlX: 20, controlY: 50, controlZ: 15, endX: 0, endY: 40, endZ: 0) },
            BezierPath3D(linesBetween: [[0, 40, 0], [0, 0, 0]])
        )
        let epsilon = 1e-3
        let inside = surface.point(at: [1 - epsilon, 0.4]), edge = surface.point(at: [1, 0.4])
        let outside = surface.point(at: [1 + epsilon, 0.4])
        // No gap: the extension starts at the edge. No crease: the steps on either side of it match.
        #expect(edge.distance(to: surface.point(at: [1 + 1e-12, 0.4])) < 1e-6)
        #expect((outside - edge).distance(to: edge - inside) < 1e-4)
    }

    @Test func `a closed interpolating surface wraps around instead of continuing`() {
        let ring = (0...8).map { index in
            let angle = Double(index % 8) * 45°
            return [Vector3D(cos(angle) * 10, sin(angle) * 10, 0), Vector3D(cos(angle) * 10, sin(angle) * 10, 10)]
        }
        let surface = InterpolatingSurface(through: ring)
        #expect(surface.point(at: [8 + 2.5, 0.5]) ≈ surface.point(at: [2.5, 0.5]))
        #expect(surface.point(at: [-1.5, 0.5]) ≈ surface.point(at: [6.5, 0.5]))
    }

    @Test(.timeLimit(.minutes(1)))
    func `draping geometry far larger than the surface's domain stays quick`() async throws {
        // A surface that wasn't remapped spans 0...1, so with 32 grid cells its tessellation step is 1/32. Refining a
        // 40 × 30 box to that made well over a million edges, and seemed to hang. The refinement is now capped at the
        // grid's own cell count across the box. This counts the triangles that come out rather than timing the
        // draping, since a timing taken while the rest of the suite runs in parallel measures the contention.
        let unremapped = RuledSurface(
            from: BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0]]),
            to: BezierPath3D(linesBetween: [[0, 30, 5], [40, 30, -5]])
        )
        let draped = Box([40, 30, 2]).draped(over: unremapped).withSegmentation(count: 32)
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: draped, in: .defaultEnvironment)
        let triangleCount = try await context.result(for: result.node).concrete.meshGL().triangles.count
        #expect(triangleCount < 2_000)
    }

    @Test func `a surface with a new domain has the same shape`() {
        let patch = BezierPatch(controlPoints: [
            [[0, 0, 0], [0, 30, 4]],
            [[40, 0, 2], [40, 30, 0]],
        ])
        let rescaled = patch.remapped(u: 10...50, v: -5...25)
        for u in Self.fractions {
            for v in Self.fractions {
                #expect(rescaled.point(at: [10 + 40 * u, -5 + 30 * v]) ≈ patch.point(at: [u, v]))
            }
        }
    }

    @Test func `geometry draped over a surface that mirrors XY is not inside out`() async throws {
        // Rows running along X put u along Y and v along X, a left-handed pair in XY. Mapping onto it mirrors the
        // geometry, which used to reverse every face and leave the solid inside out, with a negative volume.
        let rowsAlongX = BezierPatch(controlPoints: [
            [[0, 0, 0], [40, 0, 0]],
            [[0, 30, 0], [40, 30, 0]],
        ]).remapped(u: 0...30, v: 0...40)

        let draped = Box([30, 40, 2]).draped(over: rowsAlongX).withSegmentation(count: 8)
        let volume = try await draped.measurements.volume
        let bounds = try #require(try await draped.bounds)
        #expect(volume ≈ 2400)
        #expect(bounds ≈ BoundingBox3D(minimum: [0, 0, 0], maximum: [40, 30, 2]))
    }

    @Test func `geometry can be draped over any surface`() async throws {
        let surface = RuledSurface(
            from: BezierPath3D(linesBetween: [[0, 0, 0], [20, 0, 0]]),
            to: BezierPath3D(linesBetween: [[0, 20, 10], [20, 20, 10]])
        )
        let bounds = try #require(try await Box([20, 20, 1]).draped(over: surface.remapped(u: 0...20, v: 0...20)).withSegmentation(count: 8).bounds)

        #expect(bounds.minimum.z ≈ 0)
        #expect(bounds.maximum.z ≈ 11)
    }

    @available(*, deprecated)
    @Test func `the deprecated deformation still stretches the footprint over the whole surface`() async throws {
        let bounds = try #require(try await Box([10, 5, 2]).translated(x: 12, y: 20).deformed(by: Self.flatPatch).withSegmentation(count: 8).bounds)
        #expect(bounds ≈ BoundingBox3D(minimum: [0, 0, 0], maximum: [40, 30, 2]))
    }
}
