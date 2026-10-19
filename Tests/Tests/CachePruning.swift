import Foundation
import Testing
import Synchronization
@testable import Cadova

struct CachePruningTests {
    private final class Counter: Sendable {
        private let value = Atomic<Int>(0)
        func increment() { value.wrappingAdd(1, ordering: .relaxed) }
        var count: Int { value.load(ordering: .relaxed) }
    }

    @Test func `pruning to zero empties the cache, and pruned geometry is evaluated again`() async throws {
        let context = EvaluationContext()
        let geometry = Sphere(diameter: 20).subtracting { Box(10) }
        let built = try await context.buildResult(for: geometry, in: .defaultEnvironment)
        let volume = try await context.result(for: built.node).concrete.volume
        #expect(await context.approximateCacheByteCount > 0)
        #expect(await context.cache3D.count > 0)

        await context.pruneCache(toApproximateByteCount: 0)
        #expect(await context.approximateCacheByteCount == 0)
        #expect(await context.cache3D.count == 0)

        #expect(try await context.result(for: built.node).concrete.volume ≈ volume)
        #expect(await context.cache3D.hasResult(for: built.node))
    }

    @Test func `pruning keeps everything when it fits`() async throws {
        let context = EvaluationContext()
        let built = try await context.buildResult(for: Sphere(diameter: 20).subtracting { Box(10) }, in: .defaultEnvironment)
        _ = try await context.result(for: built.node)
        let count = await context.cache3D.count
        let byteCount = await context.approximateCacheByteCount

        await context.pruneCache(toApproximateByteCount: byteCount)
        #expect(await context.cache3D.count == count)
        #expect(await context.approximateCacheByteCount == byteCount)
    }

    @Test func `least recently used results are pruned first`() async throws {
        let context = EvaluationContext()
        let first = try await context.buildResult(for: Box(10), in: .defaultEnvironment).node
        let second = try await context.buildResult(for: Sphere(diameter: 10), in: .defaultEnvironment).node
        _ = try await context.result(for: first)
        _ = try await context.result(for: second)
        // Using the first again makes the second the least recently used
        let firstByteCount = try await context.result(for: first).estimatedByteCount

        await context.pruneCache(toApproximateByteCount: firstByteCount)
        #expect(await context.cache3D.hasResult(for: first))
        #expect(await !context.cache3D.hasResult(for: second))
    }

    @Test func `the estimate grows with the mesh`() async throws {
        let context = EvaluationContext()
        let coarse = try await context.result(for: Sphere(diameter: 20), in: EnvironmentValues.defaultEnvironment.withSegmentation(.fixed(16)))
        let fine = try await context.result(for: Sphere(diameter: 20), in: EnvironmentValues.defaultEnvironment.withSegmentation(.fixed(128)))
        #expect(coarse.estimatedByteCount > 0)
        #expect(fine.estimatedByteCount > coarse.estimatedByteCount * 20)
    }

    @Test func `materialized geometry is generated again after pruning`() async throws {
        let context = EvaluationContext()
        let generations = Counter()
        let materialized: BuildResult<D3> = try await context.materializedResult(key: "pruning test") {
            generations.increment()
            return try await context.result(for: Box(10), in: .defaultEnvironment)
        }
        _ = try await context.result(for: materialized.node)
        #expect(generations.count == 1)

        // A materialized node can't evaluate itself, so this relies on its generator being kept
        await context.pruneCache(toApproximateByteCount: 0)
        let result = try await context.result(for: materialized.node)
        #expect(generations.count == 2)
        #expect(result.concrete.volume ≈ 1000)
    }

    @Test func `results still being evaluated are kept`() async throws {
        let context = EvaluationContext()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
        let materialized: BuildResult<D3> = try await context.materializedResult(key: "in flight") {
            startedContinuation.yield()
            for await _ in release { break }
            return try await context.result(for: Box(10), in: .defaultEnvironment)
        }
        var startedIterator = started.makeAsyncIterator()
        _ = await startedIterator.next()

        await context.pruneCache(toApproximateByteCount: 0)
        #expect(await context.cache3D.hasResult(for: materialized.node))

        releaseContinuation.yield()
        #expect(try await context.result(for: materialized.node).concrete.volume ≈ 1000)
    }

    @Test func `a model file can still be written after its generator's cache is pruned`() async throws {
        let generator = ModelFileGenerator()
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [20, 0, 0], [20, 20, 0]])
        // A sweep caches its mesh behind a materialized node
        let file = try await generator.build(named: "pruned") {
            Circle(diameter: 4).swept(along: path, pointing: .down, toward: .direction(.down))
        }
        _ = try await file.data()
        #expect(await generator.approximateCacheByteCount > 0)

        await generator.pruneCache(toApproximateByteCount: 0)
        #expect(await generator.approximateCacheByteCount == 0)
        #expect(try await file.data().isEmpty == false)
        #expect(await generator.approximateCacheByteCount > 0)
    }
}
