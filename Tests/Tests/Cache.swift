import Foundation
import Testing
@testable import Cadova

struct GeometryCacheTests {
    let context = _EvaluationContext()
    let sphere = Sphere(diameter: 1)
    let box = Box(4)

    @Test func `cache stores and reuses evaluation results`() async throws {
        _ = try await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        let union = sphere.adding { box }

        _ = try await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)

        _ = try await context.concrete(for: union)
        await #expect(context.cache3D.count == 3)
    }

    @Test func `different environments produce separate cache entries`() async throws {
        _ = try await context.concrete(for: sphere)
        await #expect(context.cache3D.count == 1)

        _ = try await context.concrete(for: sphere, in: .defaultEnvironment.withSegmentation(.fixed(10)))
        await #expect(context.cache3D.count == 2)
    }

    @Test func `warp operations with same parameters share cache`() async throws {
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

    @Test func `split operation creates expected cache entries`() async throws {
        await #expect(context.cache3D.count == 0)

        let split1 = box.split(along: .z(2).rotated(x: 10°)) { g1, g2 in
            g1.adding(g2)
        }

        _ = try await context.concrete(for: split1)
        await #expect(context.cache3D.count == 4) // box, 2x trims, split union
    }

    @Test func `convex hull preserves part information`() async throws {
        let boxPart = Part("box")
        let model = Sphere(diameter: 10)
            .convexHull(adding: [0, 0, 20])
            .adding {
                Box(5)
                    .colored(.yellow)
                    .inPart(boxPart)
            }

        let partNames = try await model.parts.map(\.key.name)
        #expect(partNames == ["box"])
    }

    @Test func `CachedGeometry body runs once per distinct reflected key`() async throws {
        final class CallCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            var count: Int { lock.withLock { value } }
            func increment() { lock.withLock { value += 1 } }
        }

        struct Counted: CachedGeometry {
            typealias D = D3
            static let counter = CallCounter()
            let size: Double

            var body: any Geometry3D {
                Self.counter.increment()
                return Box(size)
            }
        }

        _ = try await context.concrete(for: Counted(size: 3))
        _ = try await context.concrete(for: Counted(size: 3))
        #expect(Counted.counter.count == 1)

        _ = try await context.concrete(for: Counted(size: 4))
        #expect(Counted.counter.count == 2)
    }

    @Test func `CachedGeometry key includes @Environment-read values`() async throws {
        struct EnvSensitive: CachedGeometry {
            typealias D = D3
            @Environment(\.tolerance) var tolerance

            var body: any Geometry3D {
                Box(1 + tolerance)
            }
        }

        _ = try await context.concrete(for: EnvSensitive())
        let afterFirst = await context.cache3D.count

        _ = try await context.concrete(for: EnvSensitive())
        let afterSecond = await context.cache3D.count
        #expect(afterFirst == afterSecond)

        _ = try await context.concrete(for: EnvSensitive(), in: .defaultEnvironment.withTolerance(0.5))
        let afterThird = await context.cache3D.count
        #expect(afterThird > afterSecond)
    }

    @Test func `CachedGeometry key includes a stored Geometry's built identity`() async throws {
        struct Wrapping: CachedGeometry {
            typealias D = D3
            let source: any Geometry3D

            var body: any Geometry3D { source }
        }

        _ = try await context.concrete(for: Wrapping(source: sphere))
        let afterFirst = await context.cache3D.count

        _ = try await context.concrete(for: Wrapping(source: sphere))
        let afterSecond = await context.cache3D.count
        #expect(afterFirst == afterSecond)

        _ = try await context.concrete(for: Wrapping(source: box))
        let afterThird = await context.cache3D.count
        #expect(afterThird > afterSecond)
    }

    @Test func `CachedGeometry preserves result elements set within body, including on a cache hit`() async throws {
        struct BoxInPart: CachedGeometry {
            typealias D = D3
            static let part = Part("boxInPart")
            let size: Double

            var body: any Geometry3D {
                Box(size).inPart(Self.part)
            }
        }

        let model = BoxInPart(size: 3)
            .adding {
                BoxInPart(size: 3) // Same key: reuses the first call's cached result.
                Sphere(diameter: 1)
            }

        #expect(try await model.partNames == ["boxInPart"])
    }

    @Test func `split preserves part information`() async throws {
        let boxPart = Part("box")
        let model = Sphere(diameter: 10)
            .adding {
                Box(5)
                    .colored(.yellow)
                    .inPart(boxPart)
            }
            .split(along: .z(0)) { over, under in
                over.colored(.red)
                under.colored(.blue)
            }

        let partNames = try await model.parts.map(\.key.name)
        #expect(partNames == ["box"])
    }
}
