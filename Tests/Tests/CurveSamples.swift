import Testing
import Foundation
@testable import Cadova

struct CurveSamplesTests {
    // A straight line from (0,0) to (10,0). Total arc length = 10, so a sample's
    // `distance` equals its x-coordinate.
    let line = BezierPath2D(linesBetween: [[0, 0], [10, 0]])
    let segmentation = Segmentation.fixed(10)

    @Test func `count includingEndpoints distributes samples across the full curve`() {
        let samples = line.samples(at: .count(5, endpoint: .includingEndpoints), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 2.5, 5, 7.5, 10])
        #expect(samples.first?.position ≈ [0, 0])
        #expect(samples.last?.position ≈ [10, 0])
    }

    @Test func `count excludingEnd stops one step before the curve end`() {
        let samples = line.samples(at: .count(5, endpoint: .excludingEnd), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 2, 4, 6, 8])
    }

    @Test func `step includingEndpoints with aligned stride yields the stride points`() {
        let samples = line.samples(at: .step(2.5, endpoint: .includingEndpoints), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 2.5, 5, 7.5, 10])
    }

    @Test func `step includingEndpoints with unaligned stride tacks on a final sample`() {
        let samples = line.samples(at: .step(3, endpoint: .includingEndpoints), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 3, 6, 9, 10])
    }

    @Test func `step excludingEnd with unaligned stride stops before the end`() {
        let samples = line.samples(at: .step(3, endpoint: .excludingEnd), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 3, 6, 9])
    }

    @Test func `step excludingEnd with aligned stride drops the endpoint`() {
        let samples = line.samples(at: .step(2, endpoint: .excludingEnd), segmentation: segmentation)
        #expect(samples.map(\.distance) ≈ [0, 2, 4, 6, 8])
    }

    @Test func `count zero yields no samples`() {
        let samples = line.samples(at: .count(0, endpoint: .includingEndpoints), segmentation: segmentation)
        #expect(samples.isEmpty)
    }

    @Test func `count one yields a single sample at the curve start`() {
        let samples = line.samples(at: .count(1, endpoint: .includingEndpoints), segmentation: segmentation)
        #expect(samples.count == 1)
        #expect(samples.first?.distance ≈ 0)
        #expect(samples.first?.position ≈ [0, 0])
    }

    @Test func `subcurve of a straight line uses only its restricted length`() {
        // The subcurve covers x ∈ [2.5, 7.5], so its arc length is 5.
        let middle = line[0.25...0.75]
        let samples = middle.samples(at: .count(5), segmentation: segmentation)

        #expect(samples.map(\.distance) ≈ [0, 1.25, 2.5, 3.75, 5])
        #expect(samples.map(\.position) ≈ [[2.5, 0], [3.75, 0], [5, 0], [6.25, 0], [7.5, 0]])
    }

    @Test func `subcurve is empty only when its domain has no length`() {
        #expect(line[0.25...0.75].isEmpty == false)
        #expect(line[0.5...0.5].isEmpty)
    }

    @Test func `subcurve respects step interval against its restricted length`() {
        // The subcurve covers x ∈ [2, 8], so its arc length is 6.
        let middle = line[0.2...0.8]
        let samples = middle.samples(at: .step(2), segmentation: segmentation)

        #expect(samples.map(\.distance) ≈ [0, 2, 4, 6])
        #expect(samples.map(\.position) ≈ [[2, 0], [4, 0], [6, 0], [8, 0]])
    }

    @Test func `subcurve of a quarter-circle samples land on its endpoints`() {
        // Quarter-circle around the origin from (10,0) to (0,10).
        let arc = BezierPath2D(startPoint: [10, 0]).addingArc(center: .zero, to: 90°, clockwise: false)
        // The bezier-arc covers u ∈ [0, 1]; restrict to the middle half.
        let middle = arc[0.25...0.75]
        let polyline = middle.samples(segmentation: .fixed(20))
        let totalLength = polyline.last!.distance

        let resampled = middle.samples(at: .count(5), segmentation: .fixed(20))
        #expect(resampled.count == 5)
        #expect(resampled.first?.position ≈ polyline.first?.position)
        #expect(resampled.last?.position ≈ polyline.last?.position)
        #expect(resampled.last?.distance ≈ totalLength)
    }

    @Test func `2D sample transform places origin at position with local +X along tangent`() {
        // Quarter-circle around the origin from (10,0) to (0,10), sampled at the midpoint.
        let arc = BezierPath2D(startPoint: [10, 0]).addingArc(center: .zero, to: 90°, clockwise: false)
        let samples = arc.samples(at: .count(3), segmentation: .fixed(40))
        let mid = samples[1]

        // The midpoint's tangent points "up and to the left" along the arc.
        // Applying the transform to local +X should reproduce the tangent direction at the midpoint.
        let mappedX = mid.transform.apply(to: Vector2D(x: 1, y: 0))
        let tangentTip = mid.position + mid.tangent.unitVector
        #expect(mappedX ≈ tangentTip)

        // Applying the transform to the local origin should give the sample's position.
        #expect(mid.transform.apply(to: .zero) ≈ mid.position)
    }

    @Test func `3D sample transform places origin at position with local +Z along tangent`() {
        // Straight 3D line from (0,0,0) to (0,0,10) — tangent is constant +Z, position varies along Z.
        let line3D = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 10]])
        let samples = line3D.samples(at: .count(3), segmentation: .fixed(10))
        let mid = samples[1]

        // Origin maps to position.
        #expect(mid.transform.apply(to: .zero) ≈ mid.position)

        // Local +Z maps along the tangent (a unit step in local +Z is a unit step along tangent in world).
        let mappedZ = mid.transform.apply(to: Vector3D(x: 0, y: 0, z: 1))
        let tangentTip = mid.position + mid.tangent.unitVector
        #expect(mappedZ ≈ tangentTip)
    }

    @Test func `curved path samples land on the polyline endpoints exactly`() {
        // Quarter-circle around the origin from (10,0) to (0,10).
        let arc = BezierPath2D(startPoint: [10, 0]).addingArc(center: .zero, to: 90°, clockwise: false)
        let polyline = arc.samples(segmentation: .fixed(20))
        let totalLength = polyline.last!.distance

        let resampled = arc.samples(at: .count(5, endpoint: .includingEndpoints), segmentation: .fixed(20))
        #expect(resampled.count == 5)
        #expect(resampled.first?.position ≈ polyline.first?.position)
        #expect(resampled.last?.position ≈ polyline.last?.position)
        #expect(resampled.last?.distance ≈ totalLength)
    }
}
