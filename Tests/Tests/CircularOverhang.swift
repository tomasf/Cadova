import Testing
@testable import Cadova

struct CircularOverhangTests {
    @Test func `circular overhang methods produce correct geometry`() async throws {
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

    @Test func `sphere overhangSafe extends additive relief downward`() async throws {
        let radius = 5.0
        let bounds = try #require(await Sphere(radius: radius)
            .overhangSafe(.teardrop)
            .bounds)

        #expect(bounds.minimum.z < -radius)
        #expect(bounds.maximum.z.equals(radius, within: 0.05))
    }

    @Test func `sphere overhangSafe inherits method from environment`() async throws {
        let radius = 5.0
        let plainVolume = try await Sphere(radius: radius).measurements.volume
        let overhangVolume = try await Sphere(radius: radius)
            .overhangSafe()
            .withCircularOverhangMethod(.bridge)
            .measurements.volume

        #expect(overhangVolume > plainVolume)
    }

    @Test func `sphere overhangSafe none stays inert`() async throws {
        let radius = 5.0
        let bounds = try #require(await Sphere(radius: radius)
            .overhangSafe(CircularOverhangMethod.none)
            .bounds)

        #expect(bounds.minimum.equals([-radius, -radius, -radius], within: 0.05))
        #expect(bounds.maximum.equals([radius, radius, radius], within: 0.05))
    }

    @Test func `sphere overhangSafe follows natural up direction`() async throws {
        let radius = 5.0
        let bounds = try #require(await Sphere(radius: radius)
            .overhangSafe(.teardrop)
            .definingNaturalUpDirection(.positiveX)
            .bounds)

        #expect(bounds.minimum.x < -radius)
        #expect(bounds.maximum.x.equals(radius, within: 0.05))
    }

    @Test func `sphere overhangSafe resolves relief after later transforms`() async throws {
        let radius = 5.0
        let bounds = try #require(await Sphere(radius: radius)
            .overhangSafe(.teardrop)
            .rotated(y: 90°)
            .bounds)

        #expect(bounds.minimum.z < -radius)
        #expect(bounds.maximum.z.equals(radius, within: 0.05))
    }
}
