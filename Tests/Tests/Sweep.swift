import Foundation
import Testing
@testable import Cadova

struct SweepTests {
    @Test func `shape can be swept along 3D bezier path`() async throws {
        let shape = Rectangle(x: 10, y: 6)
            .aligned(at: .center)
            .adding {
                Circle(diameter: 5)
                    .translated(x: 2, y: 3)
            }
            .subtracting {
                Rectangle(x: 8, y: 4)
                    .aligned(at: .center)
            }

        let path = BezierPath3D {
            line(x: 50)
            curve(controlX: 100, controlY: 0, controlZ: 0, endX: 100, endY: 0, endZ: 50)
            curve(controlX: 100, controlY: 0, controlZ: 150, endX: 100, endY: 50, endZ: 150)
            line(y: 100)
        }

        let sweep = shape
            .swept(along: path, pointing: .down, toward: .direction(.down))
            .withSegmentation(minAngle: 4°, minSize: 0.3)

        let m = try await sweep.measurements
        let volume = await m.volume
        let surfaceArea = await m.surfaceArea

        // Exactly one of this sweep's 1051 frames has no resolvable twist angle (the tangent is briefly
        // antiparallel to the `.down` target where the path runs vertically), bracketed by frames at 0°
        // and 90°. interpolateMissingAngles() used to hand it the preceding angle verbatim, leaving a
        // 0° → 0° → 90° step; it now interpolates to 45°. These figures are that corrected frame.
        #expect(volume ≈ 11652.769)
        #expect(surfaceArea ≈ 18070.688)
        #expect(m.boundingBox ≈ .init(minimum: [0, -5.60051, -3], maximum: [105.831, 100, 155.5]))
    }

    @Test func `star shape can be swept along 2D path`() async throws {
        let path = BezierPath2D {
            curve([10, 65], [50, -20], [60, 50])
        }

        let sweep = ExampleTests.Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))
        let m = try await sweep.measurements
        let volume = await m.volume
        let surfaceArea = await m.surfaceArea

        #expect(volume ≈ 13096.035)
        #expect(surfaceArea ≈ 9237.320)
        #expect(m.boundingBox ≈ .init(minimum: [-10.8721, -1.38221, -10.5105], maximum: [68.9987, 51.5556, 10.5105]))
    }

    @Test func `sharp corner is mitered instead of squished`() async throws {
        // Same volume-preservation invariant as Loft's equivalent test: sweeping a constant circular
        // cross-section along two straight segments meeting at a sharp corner should preserve
        // crossSectionArea * (L1 + L2), since a correct miter joint neither adds nor removes material.
        let diameter = 16.0
        let area = Double.pi * (diameter / 2) * (diameter / 2)
        let start = Vector3D(0, 0, 0), corner = Vector3D(0, 0, 40), end = Vector3D(40, 0, 40)
        let expectedVolume = area * ((corner - start).magnitude + (end - corner).magnitude)

        let path = BezierPath3D(linesBetween: [start, corner, end])
        let swept = Circle(diameter: diameter).swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))
        let m = try await swept.measurements
        let volume = await m.volume
        #expect(volume.equals(expectedVolume, within: expectedVolume * 0.01))
    }

    @Test func `overhangSafe shape swept along a horizontal path resolves relief using the first frame's orientation`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [100, 0, 0]])

        let plainSweep = Circle(diameter: 10)
            .swept(along: path, pointing: .down, toward: .direction(.down))
        let bridgeSweep = Circle(diameter: 10)
            .overhangSafe(.bridge)
            .swept(along: path, pointing: .down, toward: .direction(.down))

        let plainMeasurements = try await plainSweep.measurements
        let bridgeMeasurements = try await bridgeSweep.measurements

        // Before preserving the first frame's transform for the swept shape's build environment,
        // overhangSafe always saw a vertical (identity) up direction here, so it fell back to a plain
        // circle and this volume matched the unmodified sweep exactly. With the fix, the path's actual
        // starting orientation is visible, so bridge relief is added and the volume grows.
        let bridgeVolume = await bridgeMeasurements.volume
        let plainVolume = await plainMeasurements.volume
        #expect(bridgeVolume > plainVolume * 1.01)
    }

    private final class EvaluationCounts: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [UUID: Int] = [:]
        func increment(_ id: UUID) { lock.withLock { counts[id, default: 0] += 1 } }
        func count(_ id: UUID) -> Int { lock.withLock { counts[id, default: 0] } }
    }

    /// A path that counts how many times it's evaluated, to tell a full sampling from a cache hit.
    private struct CountedPath: ParametricCurve {
        static let counts = EvaluationCounts()
        let path: BezierPath3D
        let id: UUID

        var isEmpty: Bool { path.isEmpty }
        var domain: ClosedRange<Double> { path.domain }
        var sampleCountForLengthApproximation: Int { path.sampleCountForLengthApproximation }
        var derivativeView: any CurveDerivativeView<Vector3D> { path.derivativeView }
        func point(at u: Double) -> Vector3D {
            Self.counts.increment(id)
            return path.point(at: u)
        }
        func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [Vector3D] {
            path.points(in: range, segmentation: segmentation)
        }
        func mapPoints(_ transformer: (Vector3D) -> Vector2D) -> BezierPath2D {
            path.mapPoints(transformer)
        }
        func mapPoints(_ transformer: (Vector3D) -> Vector3D) -> Self {
            Self(path: path.mapPoints(transformer), id: id)
        }

        var evaluationCount: Int { Self.counts.count(id) }
    }

    @Test(arguments: [Segmentation.fixed(12), .adaptive(minAngle: 4°, minSize: 0.3)])
    func `repeated sweep builds sample the path only on a mesh cache miss`(segmentation: Segmentation) async throws {
        let environment = EnvironmentValues.defaultEnvironment.withSegmentation(segmentation)
        let path = CountedPath(path: .init(linesBetween: [[0, 0, 0], [20, 0, 0], [20, 20, 0]]), id: UUID())
        let sweep = Circle(diameter: 2).swept(along: path, pointing: .down, toward: .direction(.down))

        // What a single build costs on a mesh cache miss, sampling the whole path.
        _ = try await EvaluationContext().concrete(for: sweep, in: environment)
        let missCost = path.evaluationCount
        #expect(missCost > 1)

        // Every build evaluates the path's start to orient the cross-section, but concurrent copies
        // must share one sampling of the rest.
        let context = EvaluationContext()
        var before = path.evaluationCount
        _ = try await (0..<20).asyncMap { _ in
            try await context.concrete(for: sweep, in: environment)
        }
        #expect(path.evaluationCount - before <= missCost + 19)

        // A cache hit evaluates only the path's start.
        before = path.evaluationCount
        _ = try await context.concrete(for: sweep, in: environment)
        #expect(path.evaluationCount - before <= 1)

        // The cross-section and sampling settings remain part of the final geometry's key.
        before = path.evaluationCount
        let wider = Circle(diameter: 4).swept(along: path, pointing: .down, toward: .direction(.down))
        _ = try await context.concrete(for: wider, in: environment)
        #expect(path.evaluationCount - before == missCost)

        before = path.evaluationCount
        _ = try await context.concrete(for: sweep, in: environment.withSegmentation(.fixed(24)))
        #expect(path.evaluationCount - before > 1)
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
            cacheName: "SweepTests.reference"
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
