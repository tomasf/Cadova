import Foundation
import Testing
@testable import Cadova

struct GeometryCacheTests {
    let context = EvaluationContext()
    let sphere = Sphere(diameter: 1)
    let box = Box(4)

    @Test func basics() async throws {
        _ = await context.primitive(for: sphere)
        await #expect(context.cache3D.count == 1)

        let union = sphere.adding { box }

        _ = await context.primitive(for: union)
        await #expect(context.cache3D.count == 3)

        _ = await context.primitive(for: union)
        await #expect(context.cache3D.count == 3)
    }

    @Test func differentEnvironments() async throws {
        _ = await context.primitive(for: sphere)
        await #expect(context.cache3D.count == 1)

        _ = await context.primitive(for: sphere, in: .defaultEnvironment.withSegmentation(.fixed(10)))
        await #expect(context.cache3D.count == 2)
    }

    @Test func warp() async throws {
        let scale = 2.0
        let warp1 = box.warped(operationName: "test", cacheParameters: scale) {
            Vector3D($0.x + $0.z * scale, $0.y, $0.z)
        }

        _ = await context.primitive(for: warp1)
        await #expect(context.cache3D.count == 2) // sphere + warped box

        _ = await context.primitive(for: warp1)
        await #expect(context.cache3D.count == 2)

        let warp2 = box.warped(operationName: "test", cacheParameters: scale) { _ in
            Issue.record("This closure should never be reached because the cache keys are matching")
            return .zero
        }
        _ = await context.primitive(for: warp2)
        await #expect(context.cache3D.count == 2)
    }

    @Test func split() async throws {
        await #expect(context.cache3D.count == 0)

        let split1 = box.split(along: .init(z: 2).rotated(x: 10°)) { g1, g2 in
            g1.adding(g2)
        }

        _ = await context.primitive(for: split1)
        await #expect(context.cache3D.count == 6) // box, 2x splits, 2x translated splits, split union
    }
}
