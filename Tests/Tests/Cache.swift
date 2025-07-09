import Foundation
import Testing
@testable import Cadova

struct GeometryCacheTests {
    let context = EvaluationContext()
    let sphere = Sphere(diameter: 1)
    let box = Box(4)

    @Test func basics() async throws {
        _ = try await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        let union = sphere.adding { box }

        _ = try await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)

        _ = try await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)
    }

    @Test func differentEnvironments() async throws {
        _ = try await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        _ = try await context.concrete(for: sphere, in: .defaultEnvironment.withSegmentation(.fixed(10)))
        await #expect(context.cache3D.count == 2)
    }

    @Test func warp() async throws {
        let scale = 2.0
        let warp1 = box.warped(operationName: "test", cacheParameters: scale) {
            Vector3D($0.x + $0.z * scale, $0.y, $0.z)
        }

        _ = try await context.concrete(for: warp1)
        await #expect(context.cache3D.count == 2) // sphere + warped box

        _ = try await context.concrete(for: warp1)
        await #expect(context.cache3D.count == 2)

        let warp2 = box.warped(operationName: "test", cacheParameters: scale) { _ in
            Issue.record("This closure should never be reached because the cache keys are matching")
            return .zero
        }
        _ = try await context.concrete(for: warp2)
        await #expect(context.cache3D.count == 2)
    }

    @Test func split() async throws {
        await #expect(context.cache3D.count == 0)

        let split1 = box.split(along: .z(2).rotated(x: 10°)) { g1, g2 in
            g1.adding(g2)
        }

        _ = try await context.concrete(for: split1)
        await #expect(context.cache3D.count == 6) // box, 2x splits, 2x translated splits, split union
    }

    @Test func materialized() async throws {
        let cacheKey = 12

        await #expect(try context.hasCachedResult(for: cacheKey, with: D3.self) == false)
        _ = await context.storeMaterializedResult(
            try D3.Node.Result(.sphere(radius: 1, segmentCount: 10)),
            key: cacheKey
        ) as D3.Node
        await #expect(try context.hasCachedResult(for: cacheKey, with: D3.self) == true)
    }
}
