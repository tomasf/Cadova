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

        let sizes = try await ModelFileGenerator.evaluate { eval in
            var sizes: [Vector3D] = []
            for item in items {
                if let b = await eval.bounds(of: item) {
                    sizes.append(b.size)
                }
            }
            return sizes
        }

        #expect(sizes == [Vector3D(5, 5, 5), Vector3D(3, 3, 9), Vector3D(7, 4, 2)])
    }

    @Test func `outlines via evaluator match underlying outlines`() async throws {
        let shape = Rectangle([10, 4]).translated(x: 2)

        let capture = OutlineCapture()
        let reader = shape.readingOutlines { g, paths in
            capture.paths = paths
            return g
        }
        _ = try await reader.node

        let fromEvaluator = try await ModelFileGenerator.evaluate { eval in
            await eval.outlines(of: shape)
        }

        #expect(capture.paths.count == 1)
        #expect(capture.paths ≈ fromEvaluator)
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

        let (nonEmptyIsEmpty, emptyIsEmpty) = try await ModelFileGenerator.evaluate { eval in
            (await eval.isEmpty(nonEmpty), await eval.isEmpty(empty))
        }

        #expect(nonEmptyIsEmpty == false)
        #expect(emptyIsEmpty == true)
    }

    @Test func `surfaces along a segment match the existing reader`() async throws {
        let box = Box(1)
        let segment = LineSegment3D(from: [-1, 0.5, 0.5], to: [2, 0.5, 0.5])

        let crossings = try await ModelFileGenerator.evaluate { eval in
            await eval.surfaces(of: box, along: segment)
        }

        // Box of side 1 with the segment passing through the middle along x:
        // entry at x≈0 and exit at x≈1.
        #expect(crossings.count == 2)
        #expect(crossings.first!.position.x ≈ 0)
        #expect(crossings.last!.position.x ≈ 1)
    }

    @Test func `first surface from ray finds the top face`() async throws {
        let box = Box(1)

        let hit = try await ModelFileGenerator.evaluate { eval in
            await eval.firstSurface(of: box, from: [0.5, 0.5, 10], in: .down)
        }

        #expect(hit != nil)
        #expect(hit!.position.z ≈ 1)
    }

    @Test func `first surface with a transition skips the nearer crossing`() async throws {
        // 10×10×10 box with a 6×6×6 cavity: along +X the walls sit at x = -5 (entering),
        // -3 (exiting), 3 (entering) and 5 (exiting).
        let shell = Box(10).aligned(at: .center)
            .subtracting {
                Box(6).aligned(at: .center)
            }
        let segment = LineSegment3D(from: [-10, 0, 0], to: [10, 0, 0])

        let (ray, along, unfiltered, unmatched) = try await ModelFileGenerator.evaluate { eval in
            (
                await eval.firstSurface(of: shell, from: [-10, 0, 0], in: .right, transition: .exiting),
                await eval.firstSurface(of: shell, along: segment, transition: .exiting),
                await eval.firstSurface(of: shell, from: [-10, 0, 0], in: .right),
                // A ray starting inside the far wall only ever exits, so .entering matches nothing.
                await eval.firstSurface(of: shell, from: [4, 0, 0], in: .right, transition: .entering)
            )
        }

        #expect(ray?.position.x ≈ -3)
        #expect(along?.position.x ≈ -3)
        #expect(unfiltered?.position.x ≈ -5)
        #expect(unmatched == nil)
    }

    @Test func `parts ofType and single part lookup find the named part`() async throws {
        let knob = Part("knob")
        let geometry = Box(10).adding {
            Sphere(diameter: 4)
                .inPart(knob)
        }

        let (solid, single) = try await ModelFileGenerator.evaluate { eval in
            (await eval.parts(of: geometry, ofType: .solid), await eval.part(knob, of: geometry))
        }

        #expect(solid.count == 1)
        #expect(solid[knob] != nil)
        #expect(single != nil)
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

        let value = try await ModelFileGenerator.evaluate { eval in
            await eval.result(EvalTestElement.self, of: shape).value
        }

        #expect(value == 5)
    }
}

private final class OutlineCapture: @unchecked Sendable {
    var paths: [BezierPath2D] = []
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
