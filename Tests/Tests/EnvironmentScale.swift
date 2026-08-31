import Testing
import Foundation
@testable import Cadova

private final class EnvironmentProbeCapture: @unchecked Sendable {
    var segmentation: Segmentation?
    var tolerance: Double?
    var simplificationThreshold: Double?
    var scale: Double?
}

/// An empty geometry that records the environment it is built in, so a test can observe what a shape deep inside a
/// transform chain actually sees.
private struct EnvironmentProbe<D: Dimensionality>: Geometry {
    let capture: EnvironmentProbeCapture

    @GeometryBuilder<D> var body: any Geometry<D> {
        @Environment var environment
        capture.segmentation = environment.segmentation
        capture.tolerance = environment.tolerance
        capture.simplificationThreshold = environment.simplificationThreshold
        capture.scale = environment.scale
    }
}

private extension Geometry {
    /// Builds the geometry in the default environment, discarding the result.
    func build() async throws {
        _ = try await _EvaluationContext().buildResult(for: self, in: .defaultEnvironment)
    }
}

struct EnvironmentScaleTests {
    private func probing(
        _ body: (any Geometry3D) -> any Geometry3D
    ) async throws -> EnvironmentProbeCapture {
        let capture = EnvironmentProbeCapture()
        try await body(EnvironmentProbe<D3>(capture: capture)).build()
        return capture
    }

    @Test func `segmentation set inside a scale keeps its own units`() async throws {
        // The case this behavior exists for: a model authored at natural scale, given a segmentation that suits that
        // scale, and then scaled down to printable size. The scale sits above the segmentation, so it must not
        // reinterpret it.
        let capture = try await probing { probe in
            probe
                .withSegmentation(minAngle: 2°, minSize: 200)
                .scaled(0.001)
        }
        #expect(capture.segmentation == .adaptive(minAngle: 2°, minSize: 200))
    }

    @Test func `segmentation set outside a scale is measured in the outer system`() async throws {
        // The mirror image: written outside the scale, 200 means 200 units of the enclosing system, so the geometry
        // inside, which is a thousand times larger, needs a proportionally larger minimum size.
        let capture = try await probing { probe in
            probe
                .scaled(0.001)
                .withSegmentation(minAngle: 2°, minSize: 200)
        }
        #expect(capture.segmentation == .adaptive(minAngle: 2°, minSize: 200_000))
    }

    @Test func `the default segmentation stays world-relative`() async throws {
        // Nothing sets segmentation, so it keeps the reference scale it was installed at: the root.
        let capture = try await probing { probe in
            probe.scaled(0.001)
        }
        #expect(capture.segmentation == .adaptive(minAngle: 2°, minSize: 150))
    }

    @Test func `nested scales compose`() async throws {
        let capture = try await probing { probe in
            probe
                .withSegmentation(minAngle: 2°, minSize: 1)
                .scaled(4)
                .scaled(5)
        }
        #expect(capture.segmentation == .adaptive(minAngle: 2°, minSize: 1))
        #expect(capture.scale == 20)
    }

    @Test func `fixed segmentation is immune to scale`() async throws {
        let outside = try await probing { probe in
            probe.scaled(0.001).withSegmentation(count: 17)
        }
        #expect(outside.segmentation == .fixed(17))

        let inside = try await probing { probe in
            probe.withSegmentation(count: 17).scaled(0.001)
        }
        #expect(inside.segmentation == .fixed(17))
    }

    @Test func `setting and reading segmentation in the same system round trips`() async throws {
        for scale in [0.001, 1.0, 1000.0] {
            let environment = EnvironmentValues.defaultEnvironment
                .applyingTransform(Transform3D.scaling(x: scale, y: scale, z: scale))
                .withSegmentation(.adaptive(minAngle: 3°, minSize: 7))
            #expect(environment.segmentation == .adaptive(minAngle: 3°, minSize: 7))
        }
    }

    @Test func `a 2D scale contributes to the environment scale`() async throws {
        // Transform2D lifts to a Transform3D with a unit Z axis, so deriving the scale from that matrix reported 1
        // for any 2D enlargement, leaving the geometry unrefined.
        let capture = EnvironmentProbeCapture()
        try await EnvironmentProbe<D2>(capture: capture).scaled(10).build()
        #expect(capture.scale == 10)
    }

    @Test func `tolerance set inside a scale keeps its own units`() async throws {
        // A clearance describes a physical gap. Scaling the part it belongs to has to scale the gap with it, or the
        // fit the model asked for silently changes.
        let capture = try await probing { probe in
            probe
                .withTolerance(0.2)
                .scaled(0.5)
        }
        #expect(capture.tolerance == 0.2)
    }

    @Test func `tolerance set outside a scale is measured in the outer system`() async throws {
        let capture = try await probing { probe in
            probe
                .scaled(0.5)
                .withTolerance(0.2)
        }
        #expect(capture.tolerance == 0.4)
    }

    @Test func `the default tolerance stays zero at any scale`() async throws {
        // Zero has no scale to speak of, and the conversion must not turn it into a NaN.
        let capture = try await probing { probe in
            probe.scaled(0.001)
        }
        #expect(capture.tolerance == 0)
    }

    @Test func `simplification threshold set inside a scale keeps its own units`() async throws {
        let capture = try await probing { probe in
            probe
                .withSimplificationThreshold(0.01)
                .scaled(0.5)
        }
        #expect(capture.simplificationThreshold == 0.01)
    }

    @Test func `simplification threshold set outside a scale is measured in the outer system`() async throws {
        let capture = try await probing { probe in
            probe
                .scaled(0.5)
                .withSimplificationThreshold(0.01)
        }
        #expect(capture.simplificationThreshold == 0.02)
    }

    @Test func `the default simplification threshold stays world-relative`() async throws {
        let capture = try await probing { probe in
            probe.scaled(0.001)
        }
        #expect(capture.simplificationThreshold == 5)
    }

    @Test func `restoring the default simplification threshold discards the reference scale`() async throws {
        // `nil` removes the stored value rather than pinning the default at the current scale, so the default stays
        // anchored to the root wherever it is restored.
        let capture = try await probing { probe in
            probe
                .withDefaultSimplificationThreshold()
                .scaled(0.001)
                .withSimplificationThreshold(2)
        }
        #expect(capture.simplificationThreshold == 5)
    }

    @Test func `the simplification threshold reaching geometry is converted to local units`() async throws {
        // The threshold is handed to a simplify node that merges vertices in the geometry's own coordinate system,
        // so it is the converted value that has to arrive there. Under a 100x scale the default 0.005 has to become
        // 0.00005 locally to stay 0.005 in the finished model; unconverted it would merge across 0.5 units of output
        // and eat real detail.
        let node = try await Box(1).simplified().scaled(100).node
        guard case .transform(let inner, _) = node.contents,
              case .simplify(_, let tolerance) = inner.contents else {
            Issue.record("Expected a transformed simplify node, got \(node)")
            return
        }
        #expect(tolerance == 0.00005)
    }

    @Test func `a collapsed coordinate system leaves lengths alone`() async throws {
        // Scaling to nothing makes every length in that system meaningless. Passing the values through unchanged
        // beats handing the caller an infinity.
        let capture = try await probing { probe in
            probe
                .withTolerance(0.2)
                .withSegmentation(minAngle: 2°, minSize: 0.3)
                .scaled(0)
        }
        #expect(capture.tolerance == 0.2)
        #expect(capture.segmentation == .adaptive(minAngle: 2°, minSize: 0.3))
    }

    @Test func `an enlarged 2D circle is segmented for its enlarged size`() async throws {
        // A circle of radius 0.2 under the default `minSize` of 0.15 gets ⌊2π · 0.2 / 0.15⌋ = 8 segments. Scaling it
        // by 4 makes each of those segments four times as long, so it needs ⌊2π · 0.2 / (0.15 / 4)⌋ = 33 to hold the
        // same accuracy. Before 2D scaling reached the environment, both came out as 8.
        #expect(try await Circle(radius: 0.2).circleSegmentCount == 8)
        #expect(try await Circle(radius: 0.2).scaled(4).circleSegmentCount == 33)
    }
}

private extension Geometry2D {
    /// The baked segment count of a circle node, looking through a single enclosing transform.
    var circleSegmentCount: Int? {
        get async throws {
            var contents = try await node.contents
            if case .transform(let inner, _) = contents {
                contents = inner.contents
            }
            guard case .shape2D(.circle(_, let count)) = contents else { return nil }
            return count
        }
    }
}
