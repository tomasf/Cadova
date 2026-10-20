import Foundation
import Testing
@testable import Cadova

struct ModelFileGeneratorEvaluateTests {
    private struct ToleranceCube: Geometry3D {
        var body: any Geometry3D {
            @Environment(\.tolerance) var tolerance
            Box(tolerance)
        }
    }

    private struct ExpectedError: Error {}

    @Test func `evaluate returns values read through the evaluator`() async throws {
        let volume = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.measurements(of: Box([10, 5, 2])).volume
        }
        #expect(volume ≈ 100)
    }

    @Test func `evaluate applies the environment to geometry`() async throws {
        let volume = try await ModelFileGenerator.evaluate(environment: { $0.tolerance = 2 }) { evaluator in
            await evaluator.measurements(of: ToleranceCube()).volume
        }
        #expect(volume ≈ 8)
    }

    @Test func `evaluate makes the environment current for code in the closure`() async throws {
        let tolerance = try await ModelFileGenerator.evaluate(environment: { $0.tolerance = 0.25 }) { _ in
            @Environment(\.tolerance) var tolerance
            return tolerance
        }
        #expect(tolerance ≈ 0.25)
    }

    @Test func `evaluate rethrows errors from the closure`() async throws {
        await #expect(throws: ExpectedError.self) {
            try await ModelFileGenerator.evaluate { _ -> Int in
                throw ExpectedError()
            }
        }
    }

    @Test func `evaluate throws errors from building geometry`() async throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">
          <rect id="box" x="0" y="0" width="10" height="10" fill="black" />
        </svg>
        """
        let geometry = Import(svg: Data(svg.utf8), elementID: "missing", scale: .pixels)
        await #expect(throws: (any Error).self) {
            try await ModelFileGenerator.evaluate { evaluator in
                await evaluator.bounds(of: geometry)
            }
        }
    }

    @Test func `evaluations on one generator share its cache`() async throws {
        let generator = ModelFileGenerator()
        let geometry = Sphere(diameter: 20).subtracting { Box(10) }

        let volume = try await generator.evaluate { evaluator in
            await evaluator.measurements(of: geometry).volume
        }
        let byteCount = await generator.approximateCacheByteCount
        #expect(byteCount > 0)

        let repeated = try await generator.evaluate { evaluator in
            await evaluator.measurements(of: geometry).volume
        }
        #expect(repeated ≈ volume)
        #expect(await generator.approximateCacheByteCount == byteCount)
    }
}
