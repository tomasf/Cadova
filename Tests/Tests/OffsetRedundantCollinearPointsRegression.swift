import Testing
@testable import Cadova

// https://github.com/tomasf/Cadova/issues/34
// rounded(radius:)/offset(amount:style:) mangled a corner when an edge carried many redundant
// points that were exactly collinear (e.g. from a Loft's cross-section slicing). The per-vertex
// join-angle test in the offset algorithm is not robust to floating-point noise at a near-zero
// turn angle, so a run of collinear points could flip unpredictably between "straight" and
// "concave" handling and corrupt the result.
struct OffsetRedundantCollinearPointsRegressionTests {
    @Test func `removingRedundantCollinearPoints collapses a redundant point without changing the shape`() {
        let square = SimplePolygon([[0, 0], [5, 0], [10, 0], [10, 10], [0, 10]])
        let cleaned = square.removingRedundantCollinearPoints()

        #expect(cleaned.vertices == [[0, 0], [10, 0], [10, 10], [0, 10]])
        #expect(cleaned.area == square.area)
    }

    @Test func `removingRedundantCollinearPoints preserves a spike whose tip is collinear with its neighbors`() {
        // [15, 0] is exactly collinear with its neighbors [0, 0] and [10, 0], but it lies beyond
        // [10, 0] rather than between the two, so it's a real corner (a spike), not a redundant
        // midpoint, and must survive.
        let spiked = SimplePolygon([[0, 0], [15, 0], [10, 0], [10, 10], [0, 10]])
        let cleaned = spiked.removingRedundantCollinearPoints()

        #expect(cleaned.vertices.contains([15, 0]))
    }

    @Test func `rounded corner is unaffected by redundant collinear points along an edge`() async throws {
        func trapezoid(subdivisions count: Int) -> any Geometry2D {
            var points: [Vector2D] = [[-20, 10], [20, 10], [18, 0], [-18, 0]]
            for index in 1 ..< count {
                let fraction = Double(index) / Double(count)
                points.append([-18 - 2 * fraction, 10 * fraction])
            }
            return Polygon(points)
        }

        let context = _EvaluationContext()
        let clean = try await context.concrete(for: trapezoid(subdivisions: 1).rounded(radius: 2))
        let subdivided = try await context.concrete(for: trapezoid(subdivisions: 60).rounded(radius: 2))

        #expect(subdivided.area.equals(clean.area, within: 1e-6))
        #expect(subdivided.bounds.min.distance(to: clean.bounds.min) < 1e-6)
        #expect(subdivided.bounds.max.distance(to: clean.bounds.max) < 1e-6)
    }
}
