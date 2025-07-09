import Testing
@testable import Cadova

struct CircularOverhangTests {
    @Test func styles() async throws {
        try await Circle(diameter: 10)
            .overhangSafe()
            .extruded(height: 1)
            .rotated(x: 90°)
            .expectEquals(goldenFile: "circular-overhang/no-explicit-style")

        try await Circle(diameter: 10)
            .overhangSafe(CircularOverhangMethod.none)
            .extruded(height: 1)
            .rotated(x: 90°)
            .expectEquals(goldenFile: "circular-overhang/style-none")

        try await Circle(diameter: 10)
            .overhangSafe(.teardrop)
            .extruded(height: 1)
            .rotated(x: 90°)
            .expectEquals(goldenFile: "circular-overhang/additive-teardrop")

        try await Rectangle(15)
            .aligned(at: .center)
            .subtracting {
                Circle(diameter: 10)
                    .overhangSafe(.teardrop)
            }
            .extruded(height: 1)
            .rotated(x: 90°)
            .expectEquals(goldenFile: "circular-overhang/subtractive-teardrop")

        try await Rectangle(15)
            .aligned(at: .center)
            .subtracting {
                Circle(diameter: 10)
                    .overhangSafe(.bridge)
            }
            .extruded(height: 1)
            .rotated(x: 90°)
            .definingNaturalUpDirection(.down)
            .expectEquals(goldenFile: "circular-overhang/subtractive-bridge-flipped")

        try await Rectangle(15)
            .aligned(at: .center)
            .subtracting {
                Circle(diameter: 10)
                    .overhangSafe()
            }
            .extruded(height: 1)
            .rotated(x: 90°)
            .definingNaturalUpDirection(.positiveX)
            .withCircularOverhangMethod(.teardrop)
            .expectEquals(goldenFile: "circular-overhang/style-inherited")

        try await Rectangle(15)
            .aligned(at: .center)
            .subtracting {
                Circle(diameter: 10)
                    .overhangSafe(.teardrop)
            }
            .extruded(height: 1)
            .expectEquals(goldenFile: "circular-overhang/perpendicular")
    }
}
