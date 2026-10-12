import Foundation
import Testing
@testable import Cadova

struct SweepCachingTests {
    private final class SampleCounts: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [UUID: Int] = [:]
        func increment(_ id: UUID) { lock.withLock { counts[id, default: 0] += 1 } }
        func count(_ id: UUID) -> Int { lock.withLock { counts[id, default: 0] } }
    }

    private struct CountedPath: ParametricCurve {
        static let counts = SampleCounts()
        let path: BezierPath3D
        let id: UUID

        var isEmpty: Bool { path.isEmpty }
        var domain: ClosedRange<Double> { path.domain }
        var sampleCountForLengthApproximation: Int { path.sampleCountForLengthApproximation }
        var derivativeView: any CurveDerivativeView<Vector3D> { path.derivativeView }
        func point(at u: Double) -> Vector3D { path.point(at: u) }
        func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [Vector3D] {
            path.points(in: range, segmentation: segmentation)
        }
        func samples(segmentation: Segmentation) -> [CurveSample<Vector3D>] {
            Self.counts.increment(id)
            return path.samples(segmentation: segmentation)
        }
        func mapPoints(_ transformer: (Vector3D) -> Vector2D) -> BezierPath2D {
            path.mapPoints(transformer)
        }
        func mapPoints(_ transformer: (Vector3D) -> Vector3D) -> Self {
            Self(path: path.mapPoints(transformer), id: id)
        }
    }

    @Test func `repeated sweep builds sample the path only on a mesh cache miss`() async throws {
        let context = EvaluationContext()
        let environment = EnvironmentValues.defaultEnvironment.withSegmentation(.fixed(12))
        let path = CountedPath(path: .init(linesBetween: [[0, 0, 0], [20, 0, 0], [20, 20, 0]]), id: UUID())
        let sweep = Circle(diameter: 2).swept(along: path, pointing: .down, toward: .direction(.down))

        // Concurrent copies must share the concrete calculation; a hit must skip path sampling.
        _ = try await (0..<20).asyncMap { _ in
            try await context.concrete(for: sweep, in: environment)
        }
        #expect(CountedPath.counts.count(path.id) == 1)

        _ = try await context.concrete(for: sweep, in: environment)
        #expect(CountedPath.counts.count(path.id) == 1)

        // The cross-section and sampling settings remain part of the final geometry's key.
        let wider = Circle(diameter: 4).swept(along: path, pointing: .down, toward: .direction(.down))
        _ = try await context.concrete(for: wider, in: environment)
        #expect(CountedPath.counts.count(path.id) == 2)
        _ = try await context.concrete(for: sweep, in: environment.withSegmentation(.fixed(24)))
        #expect(CountedPath.counts.count(path.id) == 3)
    }

    @Test func `direct initial frame matches the sampled sequence`() throws {
        let paths = [
            BezierPath3D(linesBetween: [[0, 0, 0], [20, 0, 0], [20, 20, 0]]),
            BezierPath2D(startPoint: [10, 0]).addingArc(center: .zero, to: 90°, clockwise: false).curve3D,
            BezierPath3D(from: [3, 4, 5]) {
                curve(controlX: 3, controlY: 4, controlZ: 5, endX: 10, endY: 20, endZ: 30)
            }
        ]
        for path in paths {
            let first = try #require(path.initialFrame(reference: .down, target: .direction(.down)))
            for segmentation in [Segmentation.fixed(12), .adaptive(minAngle: 4°, minSize: 0.3)] {
                let sampled = try #require(path.frames(
                    environment: .defaultEnvironment.withSegmentation(segmentation).withMaxTwistRate(0.1°),
                    target: .direction(.down), targetReference: .down,
                    perpendicularBounds: nil, miteringCorners: true
                ).first)
                #expect(first.rigidTransform == sampled.rigidTransform)
            }
        }
    }

    @Test func `unresolved initial alignment uses the sampled orientation`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 20], [20, 0, 20]])
        #expect(path.initialFrame(reference: .down, target: .direction(.down)) == nil)
        let environment = EnvironmentValues.defaultEnvironment.withSegmentation(.fixed(12))
        let frames = path.frames(
            environment: environment, target: .direction(.down), targetReference: .down,
            perpendicularBounds: nil, miteringCorners: true
        )
        let first = try #require(frames.first)
        let shape = Circle(diameter: 4).overhangSafe(.bridge)
        let context = EvaluationContext()
        let crossSection = try await context.concrete(for: shape, in: environment.applyingTransform(first.rigidTransform))
        let expected = Mesh(
            extruding: crossSection.polygonList(), along: frames.map(\.transform),
            cacheName: "SweepCachingTests.reference"
        )
        let actual = shape.swept(along: path, pointing: .down, toward: .direction(.down))
        let expectedBuild = try await context.buildResult(for: expected, in: environment)
        let actualBuild = try await context.buildResult(for: actual, in: environment)
        let expectedMeasurements = try await Measurements(buildResult: expectedBuild, scope: .mainPart, context: context)
        let actualMeasurements = try await Measurements(buildResult: actualBuild, scope: .mainPart, context: context)
        #expect(actualMeasurements.boundingBox ≈ expectedMeasurements.boundingBox)
        let expectedVolume = await expectedMeasurements.volume
        #expect(await actualMeasurements.volume ≈ expectedVolume)
    }
}
