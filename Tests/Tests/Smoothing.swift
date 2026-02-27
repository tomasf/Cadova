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

        let context = EvaluationContext()
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
        let context = EvaluationContext()

        let original = try await context.concrete(for: source)
        let unchanged = try await context.concrete(
            for: source.withSegmentation(count: 8).smoothed(strength: 0)
        )

        #expect(unchanged.vertexCount == original.vertexCount)
        #expect(unchanged.triangleCount == original.triangleCount)
        #expect(unchanged.volume ≈ original.volume)
        #expect(unchanged.surfaceArea ≈ original.surfaceArea)
    }

    @Test
    func `smoothing strength changes cube result`() async throws {
        let source = Box(10)
        let context = EvaluationContext()
        var environment = EnvironmentValues.defaultEnvironment
        environment.segmentation = .fixed(10)

        let weak = try await context.concrete(
            for: source.smoothed(strength: 0.1),
            in: environment
        )
        let strong = try await context.concrete(
            for: source.smoothed(strength: 1),
            in: environment
        )

        #expect(strong.surfaceArea > weak.surfaceArea)
        #expect(strong.volume > weak.volume)
    }
}
