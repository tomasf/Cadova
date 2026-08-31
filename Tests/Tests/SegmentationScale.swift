import Testing
import Foundation
@testable import Cadova

private final class EnvironmentProbeCapture: @unchecked Sendable {
    var segmentation: Segmentation?
    var scale: Double?
}

/// An empty geometry that records the environment it is built in, so a test can observe what a shape deep inside a
/// transform chain actually sees.
private struct EnvironmentProbe<D: Dimensionality>: Geometry {
    let capture: EnvironmentProbeCapture

    @GeometryBuilder<D> var body: any Geometry<D> {
        @Environment var environment
        capture.segmentation = environment.segmentation
        capture.scale = environment.scale
    }
}

private extension Geometry {
    /// Builds the geometry in the default environment, discarding the result.
    func build() async throws {
        _ = try await _EvaluationContext().buildResult(for: self, in: .defaultEnvironment)
    }
}

struct SegmentationScaleTests {
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
