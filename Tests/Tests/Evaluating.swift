import Testing
@testable import Cadova

struct EvaluatingTests {
    @Test func `bounds via evaluator match measuringBounds`() async throws {
        let shape = Box([10, 8, 6]).translated(x: 3)

        let viaReader = shape.measuringBounds { _, box in
            Box(box.size).translated(box.minimum)
        }
        let viaEvaluator = shape.evaluating { g, eval in
            let box = await eval.bounds(of: g)!
            Box(box.size).translated(box.minimum)
        }

        let a = try await viaReader.bounds!
        let b = try await viaEvaluator.bounds!
        #expect(a ≈ b)
    }

    @Test func `multiple reads in one evaluating block`() async throws {
        let base = Box([20, 10, 4])
        let outer = Box([6, 6, 2])

        // Read two different bounds in one block and use both to build the result.
        let result = base.evaluating { g, eval in
            let baseBounds = await eval.bounds(of: g)!
            let outerBounds = await eval.bounds(of: outer)!
            Box(baseBounds.size).adding {
                Box(outerBounds.size)
                    .translated(z: baseBounds.maximum.z)
            }
        }

        let bounds = try await result.bounds!
        // Base extends to z=4; the box on top extends from z=4 to z=6.
        #expect(bounds.maximum.z ≈ 6)
        #expect(bounds.maximum.x ≈ 20)
    }

    @Test func `per-element loop reads each element's bounds`() async throws {
        let items: [any Geometry3D] = [
            Box([5, 5, 5]),
            Box([3, 3, 9]),
            Box([7, 4, 2]),
        ]

        let capture = SizeCapture()
        let result = Box([1, 1, 1]).evaluating { _, eval in
            var sizes: [Vector3D] = []
            for item in items {
                if let b = await eval.bounds(of: item) {
                    sizes.append(b.size)
                }
            }
            capture.sizes = sizes
            return Box([1, 1, 1])
        }
        _ = try await result.node

        #expect(capture.sizes == [Vector3D(5, 5, 5), Vector3D(3, 3, 9), Vector3D(7, 4, 2)])
    }

    @Test func `outlines via evaluator match underlying outlines`() async throws {
        let shape = Rectangle([10, 4]).translated(x: 2)

        let capture = OutlineCapture()
        let reader = shape.readingOutlines { g, paths in
            capture.fromReader = paths
            return g
        }
        _ = try await reader.node

        let evaluator = shape.evaluating { g, eval in
            capture.fromEvaluator = await eval.outlines(of: g)
            return g
        }
        _ = try await evaluator.node

        #expect(capture.fromReader.count == capture.fromEvaluator.count)
        #expect(capture.fromReader.count == 1)
    }

    @Test func `components via evaluator match separated reader`() async throws {
        let pieces = Box([4, 4, 4]).adding {
            Box([4, 4, 4]).translated(x: 10)
        }

        let viaReader = pieces.separated { components in
            Stack(.y, spacing: 1) {
                for component in components { component }
            }
        }
        let viaEvaluator = pieces.evaluating { g, eval in
            let components = await eval.components(of: g)
            Stack(.y, spacing: 1) {
                for component in components { component }
            }
        }

        let a = try await viaReader.bounds!
        let b = try await viaEvaluator.bounds!
        #expect(a ≈ b)
    }

    @Test func `isEmpty reports correctly`() async throws {
        let nonEmpty = Box([1, 1, 1])
        let empty: any Geometry3D = Empty()

        let capture = EmptyCapture()
        let probe = Box([1, 1, 1]).evaluating { _, eval in
            capture.nonEmpty = await eval.isEmpty(nonEmpty)
            capture.empty = await eval.isEmpty(empty)
            return Box([1, 1, 1])
        }
        _ = try await probe.node

        #expect(capture.nonEmpty == false)
        #expect(capture.empty == true)
    }

    @Test func `surfaces along a segment match the existing reader`() async throws {
        let box = Box(1)
        let segment = LineSegment3D(from: [-1, 0.5, 0.5], to: [2, 0.5, 0.5])

        let capture = SurfaceCapture()
        let probe = box.evaluating { g, eval in
            capture.crossings = await eval.surfaces(of: g, along: segment)
            return g
        }
        _ = try await probe.node

        // Box of side 1 with the segment passing through the middle along x:
        // entry at x≈0 and exit at x≈1.
        #expect(capture.crossings.count == 2)
        #expect(capture.crossings.first!.position.x ≈ 0)
        #expect(capture.crossings.last!.position.x ≈ 1)
    }

    @Test func `first surface from ray finds the top face`() async throws {
        let box = Box(1)

        let capture = FirstSurfaceCapture()
        let probe = box.evaluating { g, eval in
            capture.hit = await eval.firstSurface(of: g, from: [0.5, 0.5, 10], in: .down)
            return g
        }
        _ = try await probe.node

        #expect(capture.hit != nil)
        #expect(capture.hit!.position.z ≈ 1)
    }

    @Test func `first surface with a transition skips the nearer crossing`() async throws {
        // 10×10×10 box with a 6×6×6 cavity: along +X the walls sit at x = -5 (entering),
        // -3 (exiting), 3 (entering) and 5 (exiting).
        let shell = Box(10).aligned(at: .center)
            .subtracting {
                Box(6).aligned(at: .center)
            }
        let segment = LineSegment3D(from: [-10, 0, 0], to: [10, 0, 0])

        let ray = FirstSurfaceCapture()
        let along = FirstSurfaceCapture()
        let unfiltered = FirstSurfaceCapture()
        let unmatched = FirstSurfaceCapture()
        let probe = shell.evaluating { g, eval in
            ray.hit = await eval.firstSurface(of: g, from: [-10, 0, 0], in: .right, transition: .exiting)
            along.hit = await eval.firstSurface(of: g, along: segment, transition: .exiting)
            unfiltered.hit = await eval.firstSurface(of: g, from: [-10, 0, 0], in: .right)
            // A ray starting inside the far wall only ever exits, so .entering matches nothing.
            unmatched.hit = await eval.firstSurface(of: g, from: [4, 0, 0], in: .right, transition: .entering)
            return g
        }
        _ = try await probe.node

        #expect(ray.hit?.position.x ≈ -3)
        #expect(along.hit?.position.x ≈ -3)
        #expect(unfiltered.hit?.position.x ≈ -5)
        #expect(unmatched.hit == nil)
    }

    @Test func `parts ofType and single part lookup find the named part`() async throws {
        let knob = Part("knob")
        let geometry = Box(10).adding {
            Sphere(diameter: 4)
                .inPart(knob)
        }

        let capture = PartsCapture()
        let probe = geometry.evaluating { g, eval in
            capture.solid = await eval.parts(of: g, ofType: .solid)
            capture.single = await eval.part(knob, of: g)
            return g
        }
        _ = try await probe.node

        #expect(capture.solid.count == 1)
        #expect(capture.solid[knob] != nil)
        #expect(capture.single != nil)
    }

    @Test func `standalone Evaluate reads geometry captured from outer scope`() async throws {
        let base = Box([20, 10, 4])
        let outer = Box([6, 6, 2])

        let result = Evaluate { eval in
            let baseBounds = await eval.bounds(of: base)!
            let outerBounds = await eval.bounds(of: outer)!
            Box(baseBounds.size).adding {
                Box(outerBounds.size)
                    .translated(z: baseBounds.maximum.z)
            }
        }

        let bounds = try await result.bounds!
        #expect(bounds.maximum.z ≈ 6)
        #expect(bounds.maximum.x ≈ 20)
    }

    @Test func `result element via evaluator matches readingResult`() async throws {
        let shape = Box(1).withResult(EvalTestElement(value: 5))

        let capture = ResultCapture()
        let probe = shape.evaluating { g, eval in
            capture.value = await eval.result(EvalTestElement.self, of: g).value
            return g
        }
        _ = try await probe.node

        #expect(capture.value == 5)
    }
}

private final class OutlineCapture: @unchecked Sendable {
    var fromReader: [BezierPath2D] = []
    var fromEvaluator: [BezierPath2D] = []
}

private final class EmptyCapture: @unchecked Sendable {
    var nonEmpty = true
    var empty = false
}

private final class SizeCapture: @unchecked Sendable {
    var sizes: [Vector3D] = []
}

private final class SurfaceCapture: @unchecked Sendable {
    var crossings: [SurfaceCrossing] = []
}

private final class FirstSurfaceCapture: @unchecked Sendable {
    var hit: SurfaceCrossing?
}

private final class PartsCapture: @unchecked Sendable {
    var solid: [Part: any Geometry3D] = [:]
    var single: (any Geometry3D)?
}

private final class ResultCapture: @unchecked Sendable {
    var value: Int = 0
}

private struct EvalTestElement: ResultElement {
    let value: Int

    init(combining elements: [EvalTestElement]) {
        self.init(value: elements.map(\.value).reduce(0, +))
    }

    init(value: Int) {
        self.value = value
    }

    init() {
        self.init(value: 0)
    }
}
