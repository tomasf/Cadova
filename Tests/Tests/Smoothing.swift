import Testing
@testable import Cadova

struct SmoothingTests {
    @Test
    func `smoothed matches smoothOut manifold pipeline`() async throws {
        let source = Cylinder(diameter: 20, height: 10)
        let segmentation: Segmentation = .fixed(5)
        let strength = 0.75
        var environment = EnvironmentValues.defaultEnvironment
        environment.segmentation = segmentation

        let context = _EvaluationContext()
        let smoothed = try await context.concrete(
            for: source.smoothed(strength: strength),
            in: environment
        )
        let base = try await context.concrete(for: source, in: environment)
        let bounds = base.bounds
        let size = bounds.max - bounds.min
        let maxDimension = max(size.x, max(size.y, size.z))
        let segmentCount = segmentation.segmentCount(length: maxDimension)
        let maxEdgeLength = maxDimension / Double(segmentCount)
        let defaultMinSharpAngle = 60.0
        let expected = base
            .smoothOut(minSharpAngle: defaultMinSharpAngle, minSmoothness: strength)
            .refine(edgeLength: maxEdgeLength)

        #expect(smoothed.vertexCount == expected.vertexCount)
        #expect(smoothed.triangleCount == expected.triangleCount)
        #expect(smoothed.volume ≈ expected.volume)
        #expect(smoothed.surfaceArea ≈ expected.surfaceArea)
    }

    @Test
    func `zero smoothing strength leaves geometry unchanged`() async throws {
        let source = Box([10, 10, 10])

        let original = try await source.measurements
        let unchanged = try await source.withSegmentation(count: 8).smoothed(strength: 0).measurements

        #expect(unchanged.pointCount == original.pointCount)
        #expect(unchanged.triangleCount == original.triangleCount)
        #expect(await unchanged.volume ≈ original.volume)
        #expect(await unchanged.surfaceArea ≈ original.surfaceArea)
    }

    @Test
    func `smoothing strength changes cube result`() async throws {
        let source = Box(10)

        let (weak, strong) = try await ModelFileGenerator.evaluate(environment: { $0.segmentation = .fixed(10) }) { evaluator in
            let weak = await evaluator.measurements(of: source.smoothed(strength: 0.1))
            let strong = await evaluator.measurements(of: source.smoothed(strength: 1))
            return (
                (volume: await weak.volume, surfaceArea: await weak.surfaceArea),
                (volume: await strong.volume, surfaceArea: await strong.surfaceArea)
            )
        }

        #expect(strong.surfaceArea > weak.surfaceArea)
        #expect(strong.volume > weak.volume)
    }
}
