import Cadova
import Testing

struct LineTests {
    @Test
    func testContainsPointOnLine() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.contains([5, 0]))
        #expect(line.contains([0, 0]))
        #expect(!line.contains([1, 1]))
    }

    @Test
    func testClosestPoint() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.closestPoint(to: [2, 5]) ≈ [2, 0])
        #expect(line.closestPoint(to: [-3, -4]) ≈ [-3, 0])
    }

    @Test
    func testDistanceToPoint() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.distance(to: [0, 3]) ≈ 3)
        #expect(line.distance(to: [5, -5]) ≈ 5)
    }

    @Test
    func testIntersection() {
        let a = Line<D2>(point: [0, 0], direction: .positiveX)
        let b = Line<D2>(point: [0, 1], direction: .positiveY)
        #expect(a.intersection(with: b) ≈ [0, 0])

        let parallel = Line<D2>(point: [0, 1], direction: .positiveX)
        #expect(a.intersection(with: parallel) == nil)
    }

    @Test
    func test3DLineOperations() {
        let line = Line<D3>(point: [0, 0, 0], direction: .positiveZ)
        #expect(line.contains([0, 0, 10]))
        #expect(!line.contains([1, 0, 10]))

        #expect(line.closestPoint(to: [2, 5, 3]) ≈ [0, 0, 3])
        #expect(line.distance(to: [-2, -2, 0]) ≈ 8.0.squareRoot())
    }
}
