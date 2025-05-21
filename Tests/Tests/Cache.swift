import Foundation
import Testing
@testable import Cadova

struct GeometryCacheTests {
    let context = EvaluationContext()
    let sphere = Sphere(diameter: 1)
    let box = Box(4)

    @Test func basics() async throws {
        _ = await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        let union = sphere.adding { box }

        _ = await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)

        _ = await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)
    }

    @Test func differentEnvironments() async throws {
        _ = await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        _ = await context.concrete(for: sphere, in: .defaultEnvironment.withSegmentation(.fixed(10)))
        await #expect(context.cache3D.count == 2)
    }

    @Test func warp() async throws {
        let scale = 2.0
        let warp1 = box.warped(operationName: "test", cacheParameters: scale) {
            Vector3D($0.x + $0.z * scale, $0.y, $0.z)
        }

        _ = await context.concrete(for: warp1)
        await #expect(context.cache3D.count == 2) // sphere + warped box

        _ = await context.concrete(for: warp1)
        await #expect(context.cache3D.count == 2)

        let warp2 = box.warped(operationName: "test", cacheParameters: scale) { _ in
            Issue.record("This closure should never be reached because the cache keys are matching")
            return .zero
        }
        _ = await context.concrete(for: warp2)
        await #expect(context.cache3D.count == 2)
    }

    @Test func split() async throws {
        await #expect(context.cache3D.count == 0)

        let split1 = box.split(along: .z(2).rotated(x: 10°)) { g1, g2 in
            g1.adding(g2)
        }

        _ = await context.concrete(for: split1)
        await #expect(context.cache3D.count == 6) // box, 2x splits, 2x translated splits, split union
    }

    @Test func materialized() async throws {
        let cacheKey = 12

        await #expect(context.hasCachedResult(for: cacheKey, with: D3.self) == false)
        _ = await context.storeMaterializedResult(
            D3.Node.Result(.sphere(radius: 1, segmentCount: 10)),
            key: cacheKey
        ) as D3.Node
        await #expect(context.hasCachedResult(for: cacheKey, with: D3.self) == true)
    }

    @Test func boxed() async throws {
        let counter = AsyncCounter()

        // Plain geometry
        let g = CallbackGeometry {
            await counter.increment()
        }
        await g.triggerEvaluation()
        await #expect(counter.value == 1)

        // Measuring evaluates twice
        await counter.reset()
        let measuredG = g.measuring { input, _ in
            input
        }
        await measuredG.triggerEvaluation()
        await #expect(counter.value == 2)

        // Boxing caches evaluation
        await counter.reset()
        let boxedG = g.cached(as: "test", parameters: 1)
        let measuredBoxedG = boxedG.measuring { input, _ in
            input
        }
        await measuredBoxedG.triggerEvaluation()
        await #expect(counter.value == 1)
    }
}

fileprivate struct CallbackGeometry: Geometry {
    typealias D = D3

    let callback: @Sendable () async -> ()

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        await callback()
        return .init(.empty)
    }
}

actor AsyncCounter {
    var value = 0
    func increment() async {
        value += 1
    }
    func reset() async {
        value = 0
    }
}
