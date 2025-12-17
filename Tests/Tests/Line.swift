import Cadova
import Testing

struct LineTests {
    @Test
    func `line correctly identifies points on itself`() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.contains([5, 0]))
        #expect(line.contains([0, 0]))
        #expect(!line.contains([1, 1]))
    }

    @Test
    func `line can be translated while preserving direction`() {
        let original = Line<D3>(point: [1, 2, 3], direction: .positiveZ)
        let translated = original.translated(x: 3, y: -2, z: 1)
        #expect(translated.point ≈ [4, 0, 4])
        #expect(translated.direction ≈ original.direction)
    }

    @Test
    func `line can be rotated`() {
        let line = Line<D3>(point: [1, 0, 0], direction: .positiveY)
        let rotated = line.rotated(x: 0°, y: 0°, z: 90°)
        #expect(rotated.direction ≈ .negativeX)

        let expectedDir = Vector3D(x: -1, y: 0, z: 0)
        #expect(rotated.direction.unitVector ≈ expectedDir.normalized)
    }

    @Test
    func `line finds closest point to external point`() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.closestPoint(to: [2, 5]) ≈ [2, 0])
        #expect(line.closestPoint(to: [-3, -4]) ≈ [-3, 0])
    }

    @Test
    func `line calculates distance to external point`() {
        let line = Line<D2>(point: [0, 0], direction: .positiveX)
        #expect(line.distance(to: [0, 3]) ≈ 3)
        #expect(line.distance(to: [5, -5]) ≈ 5)
    }

    @Test
    func `lines can find intersection point`() {
        let a = Line<D2>(point: [0, 0], direction: .positiveX)
        let b = Line<D2>(point: [0, 1], direction: .positiveY)
        #expect(a.intersection(with: b) ≈ [0, 0])

        let parallel = Line<D2>(point: [0, 1], direction: .positiveX)
        #expect(a.intersection(with: parallel) == nil)
    }

    @Test
    func `3D line operations work correctly`() {
        let line = Line<D3>(point: [0, 0, 0], direction: .positiveZ)
        #expect(line.contains([0, 0, 10]))
        #expect(!line.contains([1, 0, 10]))

        #expect(line.closestPoint(to: [2, 5, 3]) ≈ [0, 0, 3])
        #expect(line.distance(to: [-2, -2, 0]) ≈ 8.0.squareRoot())
    }
}
