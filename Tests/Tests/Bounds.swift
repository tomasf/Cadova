import Testing
@testable import Cadova

struct BoundsTests {
    @Test func `2D shape alignment affects bounds`() async throws {
        let geometry = Rectangle([10, 4])
            .aligned(at: .centerX, .top)

        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -4], maximum: [5, 0]))
    }

    @Test func `conflicting alignments are resolved left to right`() async throws {
        let geometry = Rectangle([50, 20])
            .aligned(at: .minX, .centerX, .centerY, .maxX)

        #expect(try await geometry.bounds ≈ .init(minimum: [-50, -10], maximum: [0, 10]))
    }

    @Test func `repeated alignments accumulate correctly`() async throws {
       let geometry = Box([10, 8, 12])
            .aligned(at: .minX)
            .aligned(at: .maxY)
            .aligned(at: .centerX, .centerY)
            .aligned(at: .maxX)
            .aligned(at: .centerXY)

        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -4, 0], maximum: [5, 4, 12]))
    }

    @Test func `bounds are correctly calculated after transforms`() async throws {
        let base = Box([10, 8, 12])
            .rotated(x: 90°)
            .translated(y: 12)

        let extended = base
            .scaled(z: 1.25)
            .sheared(.x, along: .y, factor: 1.5)

        #expect(try await base.bounds ≈ Box([10, 12, 8]).bounds)
        #expect(try await extended.bounds ≈ .init(minimum: .zero, maximum: [28, 12, 10]))
    }

    @Test func `stack computes combined bounds of children`() async throws {
        let geometry = Stack(.x, spacing: 1, alignment: .min) {
            Box([10, 8, 12])
            RegularPolygon(sideCount: 8, apothem: 3)
                .rotated(22.5°)
                .extruded(height: 1)
            Rectangle([2, 5])
                .scaled(x: 2)
                .extruded(height: 3)
        }

        #expect(try await geometry.bounds ≈ .init(minimum: .zero, maximum: [22, 8, 12]))
    }
}
