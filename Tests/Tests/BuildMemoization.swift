import Foundation
import Testing
@testable import Cadova

/// Reader operations — `measuring`, `separated`, `readingOutlines`, `readingSurfaces`, `evaluating` —
/// have to build their target before they can hand anything to their closure. If the closure then
/// receives the *source geometry* rather than what that build produced, building the closure's result
/// walks the same subtree a second time, and nesting `k` readers walks the base `2^k` times.
///
/// These tests pin the build count of a leaf that counts its own `body` evaluations. They also pin the
/// correctness constraint that keeps the memo honest: the environment a subtree is built in is part of
/// its identity, so a closure that hands its geometry a different environment — explicitly with an
/// environment modifier, or implicitly by transforming it, since the accumulated transform lives in
/// the environment — must still get a real rebuild.
struct BuildMemoizationTests {
    // MARK: - Instrumentation

    struct BuildObservation: Hashable, Sendable {
        let segmentation: Segmentation
        let transform: Transform3D
    }

    final class BuildCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var observations: [BuildObservation] = []

        var value: Int { lock.withLock { observations.count } }
        var recorded: [BuildObservation] { lock.withLock { observations } }
        var recordedSegmentations: [Segmentation] { recorded.map(\.segmentation) }

        func record(_ observation: BuildObservation) {
            lock.withLock { observations.append(observation) }
        }
    }

    /// A leaf shape that records every evaluation of its `body`, along with the environment it saw.
    struct CountingBox: Geometry3D {
        let counter: BuildCounter
        var size: Double = 10

        var body: any Geometry3D {
            @Environment(\.segmentation) var segmentation
            @Environment(\.transform) var transform
            let _ = counter.record(.init(segmentation: segmentation, transform: transform))
            Box(size)
        }
    }

    /// Disjoint shells, so `separated` sees more than one component.
    struct CountingShells: Geometry3D {
        static let shellSize = 5.0
        /// Wider than a shell, so consecutive shells never touch and stay separate components.
        static let shellSpacing = 10.0

        let counter: BuildCounter
        let shellCount: Int

        var body: any Geometry3D {
            @Environment(\.segmentation) var segmentation
            @Environment(\.transform) var transform
            let _ = counter.record(.init(segmentation: segmentation, transform: transform))
            Box(Self.shellSize)
                .repeated(along: .x, in: 0..<(Self.shellSpacing * Double(shellCount)), count: shellCount)
        }
    }

    struct CountingCircle: Geometry2D {
        let counter: BuildCounter

        var body: any Geometry2D {
            @Environment(\.segmentation) var segmentation
            @Environment(\.transform) var transform
            let _ = counter.record(.init(segmentation: segmentation, transform: transform))
            Circle(diameter: 10)
        }
    }

    @discardableResult
    private func build<D: Dimensionality>(
        _ geometry: D.Geometry,
        in environment: EnvironmentValues = .defaultEnvironment
    ) async throws -> (context: EvaluationContext, result: BuildResult<D>) {
        let context = EvaluationContext()
        let result = try await context.buildResult(for: geometry, in: environment)
        return (context, result)
    }

    // MARK: - Build counts

    @Test func `a measuring closure that leaves its geometry in place builds the target once`() async throws {
        let counter = BuildCounter()
        let geometry = CountingBox(counter: counter)
            .measuringBounds { geometry, box in
                geometry.intersecting { Box(box.size * 0.5) }
            }

        try await build(geometry)
        #expect(counter.value == 1)
    }

    @Test func `four nested measuring modifiers build the leaf once`() async throws {
        let counter = BuildCounter()
        var geometry: any Geometry3D = CountingBox(counter: counter)
        for _ in 0..<4 {
            geometry = geometry.measuringBounds { inner, box in
                inner.intersecting { Box(box.size) }
            }
        }

        try await build(geometry)
        #expect(counter.value == 1)
    }

    @Test func `separated builds its source once regardless of part count`() async throws {
        for shellCount in [1, 2, 5] {
            let counter = BuildCounter()
            let geometry = CountingShells(counter: counter, shellCount: shellCount)
                .separated { components in
                    for component in components {
                        component
                    }
                }

            try await build(geometry)
            #expect(counter.value == 1, "shellCount: \(shellCount)")
        }
    }

    @Test func `readingSurfaces builds its target once`() async throws {
        let counter = BuildCounter()
        let geometry = CountingBox(counter: counter)
            .readingSurfaces(from: [5, 5, 100], in: .down) { geometry, _ in
                geometry
            }

        try await build(geometry)
        #expect(counter.value == 1)
    }

    @Test func `evaluating builds its target once`() async throws {
        let counter = BuildCounter()
        let geometry = CountingBox(counter: counter)
            .evaluating { geometry, evaluator in
                let _ = await evaluator.bounds(of: geometry)
                let _ = await evaluator.bounds(of: geometry)
                return geometry
            }

        try await build(geometry)
        #expect(counter.value == 1)
    }

    @Test func `readingOutlines builds its target once`() async throws {
        let counter = BuildCounter()
        let geometry = CountingCircle(counter: counter)
            .readingOutlines { geometry, _ in
                geometry
            }

        try await build(geometry)
        #expect(counter.value == 1)
    }

    @Test func `trimming builds its target once`() async throws {
        let counter = BuildCounter()
        try await build(CountingCircle(counter: counter).trimmed(along: .y))
        #expect(counter.value == 1)
    }

    // `split(along:)` is two independent `trimmed(along:)` calls, so it builds its target once per
    // half rather than the two-per-half it used to.
    @Test func `splitting builds its target once per half`() async throws {
        let counter = BuildCounter()
        let geometry = CountingCircle(counter: counter)
            .split(along: .y) { right, left in
                right
                left.translated(x: 20)
            }

        try await build(geometry)
        #expect(counter.value == 2)
    }

    // MARK: - Environment correctness

    // A builder closure may legitimately wrap the geometry it was handed in an environment modifier.
    // Memoizing the build must not swallow that: the subtree has to be rebuilt under the new
    // environment, and the result must reflect the inner environment, not the outer one.
    @Test func `a builder closure's environment modifier still reaches the measured geometry`() async throws {
        let counter = BuildCounter()
        let outerSegmentation = Segmentation.fixed(11)
        let innerSegmentation = Segmentation.fixed(23)

        let geometry = CountingBox(counter: counter)
            .measuringBounds { geometry, _ in
                geometry.withSegmentation(innerSegmentation)
            }
            .withSegmentation(outerSegmentation)

        try await build(geometry)

        #expect(counter.recordedSegmentations == [outerSegmentation, innerSegmentation])
    }

    // The same, observed through the geometry itself rather than an environment probe: the number of
    // segments in the produced circle must come from the closure's environment.
    @Test func `a builder closure's segmentation change is visible in the produced geometry`() async throws {
        let geometry = Circle(diameter: 10)
            .measuringBounds { circle, _ in
                circle.withSegmentation(count: 7)
            }
            .withSegmentation(count: 31)

        let (context, result) = try await build(geometry) as (EvaluationContext, BuildResult<D2>)
        let concrete = try await context.result(for: result.node).concrete
        let vertexCount = concrete.polygonList().polygons.first?.vertices.count

        #expect(vertexCount == 7)
    }

    // Without an environment modifier, the measured geometry keeps the outer environment.
    @Test func `a builder closure without an environment modifier keeps the outer environment`() async throws {
        let counter = BuildCounter()
        let outerSegmentation = Segmentation.fixed(11)

        let geometry = CountingBox(counter: counter)
            .measuringBounds { geometry, _ in geometry }
            .withSegmentation(outerSegmentation)

        try await build(geometry)

        #expect(counter.recordedSegmentations == [outerSegmentation])
    }

    // Transforming the geometry inside the closure is an environment change too: the accumulated
    // transform lives in the environment, and geometry is allowed to read it (natural up direction,
    // scaled tolerance and segmentation, anchors). So `aligned` and friends genuinely build their
    // target twice — once to measure it in the untransformed frame, once to place it in the
    // transformed one — and the two builds must see the two different transforms. This is the limit
    // of an environment-keyed memo, not a defect in it.
    @Test func `a measuring closure that transforms its geometry rebuilds it under the new transform`() async throws {
        let boxSize = 12.0
        let counter = BuildCounter()
        try await build(CountingBox(counter: counter, size: boxSize).aligned(at: .centerXY))

        #expect(counter.value == 2)
        #expect(counter.recorded.map(\.transform)
            == [.identity, .translation(x: -boxSize / 2, y: -boxSize / 2)])
    }

    /// The same limit holds for every member of the transform-applying family, not only `aligned`.
    /// Each of these decides where its geometry goes, so each builds it twice: once to measure it
    /// where it stands, once to build it where it was put. Pinning one member would leave the other
    /// four free to change without anyone noticing.
    @Test func `every transform-applying modifier rebuilds its geometry under the new transform`() async throws {
        func buildCount(_ place: (CountingBox) -> any Geometry3D) async throws -> Int {
            let counter = BuildCounter()
            try await build(place(CountingBox(counter: counter)))
            return counter.value
        }

        #expect(try await buildCount { $0.aligned(at: .centerXY) } == 2)
        #expect(try await buildCount { $0.whileAligned(at: .centerXY) { $0 } } == 2)
        #expect(try await buildCount { $0.resized(x: 20, y: 20, z: 20) } == 2)
        #expect(try await buildCount { box in Stack(.x, spacing: 1) { box; Box(1) } } == 2)

        // `within` is the one that doesn't, measured rather than assumed: it decides on a translation
        // and applies it to the build it already has, instead of building the geometry again in the
        // moved frame. So it takes the memo like the readers do.
        #expect(try await buildCount { $0.within(0...20, along: .x) } == 1)
    }

    // MARK: - Stand-in scoping

    // A stand-in replays a build only in the context that produced it. A `.materialized` node's
    // generator is declared on one context's cache, so replaying such a result in a different
    // context would hand back a node that context can't evaluate.
    @Test func `a stand-in rebuilds rather than replaying in a different context`() async throws {
        let counter = BuildCounter()
        let source: any Geometry3D = CountingBox(counter: counter)
        let environment = EnvironmentValues.defaultEnvironment

        let contextA = EvaluationContext()
        let resultA = try await contextA.buildResult(for: source, in: environment)
        let standIn = resultA.standingIn(for: source, in: environment, context: contextA)
        #expect(counter.value == 1)

        _ = try await contextA.buildResult(for: standIn, in: environment)
        #expect(counter.value == 1)

        let contextB = EvaluationContext()
        _ = try await contextB.buildResult(for: standIn, in: environment)
        #expect(counter.value == 2)
    }
}
