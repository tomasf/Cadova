import Testing
@testable import Cadova

struct SplitTests {
    @Test func `geometry can be split along angled plane`() async throws {
        let split = Box(10)
            .aligned(at: .center)
            .split(along: .z(0).rotated(x: 20°)) {
                $0.colored(.red)
                $1.colored(.blue)
            }

        try await split.expectEquals(goldenFile: "splitAlongPlane")
    }

    @Test func `split parts have correct measurements`() async throws {
        let topMeasurements = try await Box(10)
            .split(along: .z(2)) { a, _ in a }
            .measurements

        #expect(topMeasurements.volume ≈ 800.0)
        #expect(topMeasurements.boundingBox?.minimum.z ≈ 2)

        let bottomMeasurements = try await Box(10)
            .split(along: .z(2)) { _, b in b }
            .measurements

        #expect(bottomMeasurements.volume ≈ 200.0)
        #expect(bottomMeasurements.boundingBox?.minimum.z ≈ 0)
    }

    @Test func `separated correctly identifies disjoint components`() async throws {
        let merged: any Geometry3D = Box(1).adding { Box(1).translated(x: 0.5) }
            .separated { components in
                #expect(components.count == 1)
                Union(children: components)
            }
        try await merged.triggerEvaluation()

        let merged2: any Geometry3D = Box(1).adding { Box(1).translated(x: 1.1) }
            .separated { components in
                #expect(components.count == 2)
                Union(children: components)
            }
        try await merged2.triggerEvaluation()
    }

    @Test func `3D split by single axis range produces correct halves`() async throws {
        let upper = try await Box(10)
            .split(z: 5.0...) { inside, _ in inside }
            .measurements

        #expect(upper.volume ≈ 500)
        #expect(upper.boundingBox?.minimum.z ≈ 5)
        #expect(upper.boundingBox?.maximum.z ≈ 10)

        let lower = try await Box(10)
            .split(z: 5.0...) { _, outside in outside }
            .measurements

        #expect(lower.volume ≈ 500)
        #expect(lower.boundingBox?.minimum.z ≈ 0)
        #expect(lower.boundingBox?.maximum.z ≈ 5)
    }

    @Test func `3D split by closed range extracts a slab`() async throws {
        let slab = try await Box(10)
            .split(z: 2.0...8.0) { inside, _ in inside }
            .measurements

        #expect(slab.volume ≈ 600)
        #expect(slab.boundingBox?.minimum.z ≈ 2)
        #expect(slab.boundingBox?.maximum.z ≈ 8)

        let rest = try await Box(10)
            .split(z: 2.0...8.0) { _, outside in outside }
            .measurements

        #expect(rest.volume ≈ 400)
    }

    @Test func `3D split with multi-axis ranges extracts a sub-box`() async throws {
        let inside = try await Box(10)
            .split(x: 2.0...8.0, z: 2.0...8.0) { inside, _ in inside }
            .measurements

        #expect(inside.volume ≈ 360)
        #expect(inside.boundingBox?.minimum ≈ [2, 0, 2])
        #expect(inside.boundingBox?.maximum ≈ [8, 10, 8])
    }

    @Test func `3D split with nil ranges keeps full geometry inside`() async throws {
        let inside = try await Box(10)
            .split { inside, _ in inside }
            .measurements

        #expect(inside.volume ≈ 1000)
    }

    @Test func `2D split by single axis range produces correct halves`() async throws {
        let upper = try await Rectangle(10)
            .split(y: 5.0...) { inside, _ in inside }
            .measurements

        #expect(upper.area ≈ 50)
        #expect(upper.boundingBox?.minimum ≈ [0, 5])
        #expect(upper.boundingBox?.maximum ≈ [10, 10])

        let lower = try await Rectangle(10)
            .split(y: 5.0...) { _, outside in outside }
            .measurements

        #expect(lower.area ≈ 50)
        #expect(lower.boundingBox?.minimum ≈ [0, 0])
        #expect(lower.boundingBox?.maximum ≈ [10, 5])
    }

    @Test func `2D split with multi-axis ranges extracts a sub-rectangle`() async throws {
        let inside = try await Rectangle(10)
            .split(x: 2.0...8.0, y: 2.0...8.0) { inside, _ in inside }
            .measurements

        #expect(inside.area ≈ 36)
        #expect(inside.boundingBox?.minimum ≈ [2, 2])
        #expect(inside.boundingBox?.maximum ≈ [8, 8])
    }

    @Test func `2D split with mask separates inside and outside`() async throws {
        let mask: any Geometry2D = Circle(radius: 3).translated(x: 5, y: 5)

        let inside = try await Rectangle(10)
            .split(with: { mask }) { inside, _ in inside }
            .measurements

        let circleArea = Double.pi * 9
        #expect(inside.area.equals(circleArea, within: 0.05))

        let outside = try await Rectangle(10)
            .split(with: { mask }) { _, outside in outside }
            .measurements

        let outsideArea = 100 - circleArea
        #expect(outside.area.equals(outsideArea, within: 0.05))
    }

    @Test func `separated components can be stacked`() async throws {
        let model = Sphere(diameter: 10)
            .subtracting {
                Box([12, 12, 1])
                    .aligned(at: .center)
            }

        try await
        model.separated { components in
            Stack(.x, spacing: 1) {
                for component in components {
                    component
                }
            }
        }
        .expectEquals(goldenFile: "separatedExample")
    }
}
