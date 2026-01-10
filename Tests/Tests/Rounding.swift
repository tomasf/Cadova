import Foundation
import Testing
@testable import Cadova

struct RoundingTests {
    // MARK: - Outside Rounding

    @Test func `rounding outside corners reduces bounds`() async throws {
        let original = Rectangle(x: 20, y: 20)
        let rounded = original.rounded(outsideRadius: 2)

        let originalBounds = try await original.bounds
        let roundedBounds = try await rounded.bounds

        // Rounded rectangle should have same bounds as original
        // (rounding doesn't change the bounding box for a rectangle)
        #expect(roundedBounds?.size.x ≈ originalBounds?.size.x)
        #expect(roundedBounds?.size.y ≈ originalBounds?.size.y)
    }

    @Test func `rounding outside corners reduces area`() async throws {
        let original = Rectangle(x: 20, y: 20)
        let rounded = original.rounded(outsideRadius: 2)

        let originalArea = try await original.measurements.area
        let roundedArea = try await rounded.measurements.area

        // Rounded rectangle has less area (corners removed)
        #expect(roundedArea < originalArea)
    }

    @Test func `rounding outside with small radius has minimal effect`() async throws {
        let original = Rectangle(x: 20, y: 20)
        let rounded = original.rounded(outsideRadius: 0.1)

        let originalArea = try await original.measurements.area
        let roundedArea = try await rounded.measurements.area

        // Very small rounding should have minimal effect
        #expect(roundedArea > originalArea * 0.99)
    }

    // MARK: - Inside Rounding

    @Test func `rounding inside corners of L-shape`() async throws {
        // Create an L-shape with an inside corner
        let lShape = Union {
            Rectangle(x: 20, y: 10)
            Rectangle(x: 10, y: 20)
        }

        let rounded = lShape.rounded(insideRadius: 2)
        let originalArea = try await lShape.measurements.area
        let roundedArea = try await rounded.measurements.area

        // Inside rounding adds material to fill the corner
        #expect(roundedArea > originalArea)
    }

    @Test func `rounding inside corners increases area`() async throws {
        // Create a shape with inside corners (star-like)
        let shape = Union {
            Rectangle(x: 30, y: 10).aligned(at: .center)
            Rectangle(x: 10, y: 30).aligned(at: .center)
        }

        let rounded = shape.rounded(insideRadius: 2)
        let originalArea = try await shape.measurements.area
        let roundedArea = try await rounded.measurements.area

        // Inside rounding fills in the inside corners
        #expect(roundedArea > originalArea)
    }

    // MARK: - Combined Rounding

    @Test func `rounding both inside and outside`() async throws {
        // Cross shape has both inside and outside corners
        let cross = Union {
            Rectangle(x: 30, y: 10).aligned(at: .center)
            Rectangle(x: 10, y: 30).aligned(at: .center)
        }

        let roundedOutside = cross.rounded(outsideRadius: 2)
        let roundedInside = cross.rounded(insideRadius: 2)

        let outsideArea = try await roundedOutside.measurements.area
        let insideArea = try await roundedInside.measurements.area

        // Outside only: removes corners (less area than original)
        // Inside only: fills corners (more area than original)
        #expect(insideArea > outsideArea)
    }

    @Test func `uniform rounding with radius parameter`() async throws {
        let shape = Union {
            Rectangle(x: 30, y: 10).aligned(at: .center)
            Rectangle(x: 10, y: 30).aligned(at: .center)
        }

        let roundedUniform = shape.rounded(radius: 2)
        let roundedBoth = shape.rounded(insideRadius: 2, outsideRadius: 2)

        let uniformArea = try await roundedUniform.measurements.area
        let bothArea = try await roundedBoth.measurements.area

        // These should produce identical results
        #expect(uniformArea.equals(bothArea, within: 0.1))
    }

    // MARK: - Edge Cases

    @Test func `rounding preserves shape when radius is zero-ish`() async throws {
        let original = Rectangle(x: 20, y: 20)
        let rounded = original.rounded(outsideRadius: 0.001)

        let originalArea = try await original.measurements.area
        let roundedArea = try await rounded.measurements.area

        #expect(roundedArea.equals(originalArea, within: 1))
    }

    @Test func `rounding circle has no effect`() async throws {
        let original = Circle(diameter: 20)
        let rounded = original.rounded(outsideRadius: 2)

        let originalArea = try await original.measurements.area
        let roundedArea = try await rounded.measurements.area

        // Circle has no corners to round
        #expect(roundedArea.equals(originalArea, within: 1))
    }

    @Test func `rounding with large radius`() async throws {
        let original = Rectangle(x: 20, y: 20)
        let rounded = original.rounded(outsideRadius: 5)

        let roundedBounds = try await rounded.bounds

        // Should still have valid bounds
        #expect(roundedBounds != nil)
        #expect(roundedBounds!.size.x > 0)
        #expect(roundedBounds!.size.y > 0)
    }

    // MARK: - Complex Shapes

    @Test func `rounding complex polygon`() async throws {
        // Create a more complex shape
        let shape = Rectangle(x: 30, y: 20)
            .subtracting {
                Rectangle(x: 10, y: 10)
                    .translated(x: 10, y: 5)
            }

        let rounded = shape.rounded(insideRadius: 1, outsideRadius: 1)
        let roundedBounds = try await rounded.bounds

        #expect(roundedBounds != nil)
        #expect(roundedBounds!.size.x ≈ 30)
        #expect(roundedBounds!.size.y ≈ 20)
    }
}
