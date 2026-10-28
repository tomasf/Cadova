import Foundation
import Testing
import Manifold3D
@_spi(ConcreteInternals) @testable import Cadova

struct LazyEvaluationTests {
    /// A Manifold carrying an error. The smooth initializer reports a bad mesh through the
    /// Manifold's status instead of throwing, so the error stays inside the value.
    static var failedManifold: Cadova.Manifold {
        let mesh = MeshGL<Vector3D>(
            vertices: [Vector3D(0, 0, 0), Vector3D(1, 0, 0), Vector3D(0, 1, 0)],
            triangles: [Manifold3D.Triangle(0, 1, 3)]
        )
        return Cadova.Manifold(meshGL: mesh, smoothEdges: [:])
    }

    /// A transformed result carrying an error, as a build result. Transformed results aren't
    /// validated, so the error travels with it until the output checks it.
    static func failedTransformedResult(in context: EvaluationContext) async throws -> BuildResult<D3> {
        let failed = failedManifold
        #expect(failed.status != nil)

        return try await context.materializedResult(key: "lazy evaluation failure") {
            EvaluationResult<D3>(unvalidatedParts: [failed], materialMapping: [:])
                .transformed(Transform3D.translation(x: 2))
        }
    }

    @Test func `a Boolean result is validated when it's made`() throws {
        let box = try EvaluationResult<D3>(Cadova.Manifold.cube(size: Vector3D(1, 1, 1)))
        #expect(throws: ManifoldError.self) {
            _ = try EvaluationResult<D3>(product: Self.failedManifold.boolean(.union, with: box.concrete), results: [box])
        }
    }

    @Test func `STL output fails for an error in an unvalidated result`() async throws {
        let context = EvaluationContext()
        let result = try await Self.failedTransformedResult(in: context)
        let provider = BinarySTLDataProvider(result: result, options: [])

        await #expect(throws: ManifoldError.self) { try await provider.evaluate(context: context) }
        await #expect(throws: ManifoldError.self) { _ = try await provider.generateOutput(context: context) }
    }

    @Test func `3MF output fails for an error in an unvalidated result`() async throws {
        let context = EvaluationContext()
        let result = try await Self.failedTransformedResult(in: context)
        let provider = ThreeMFDataProvider(result: result, options: [], environment: .defaultEnvironment)

        await #expect(throws: ManifoldError.self) { try await provider.evaluate(context: context) }
        await #expect(throws: ManifoldError.self) { _ = try await provider.generateOutput(context: context) }
    }
}
