import Foundation
import Testing
@testable import Cadova

struct RepeatAlongTests {
    // MARK: - Repeat with Step

    @Test func `3D repeat along X with step`() async throws {
        let geometry = Box(5).repeated(along: .x, in: 0..<30, step: 10)
        let bounds = try await geometry.bounds

        // Copies at x=0, 10, 20 (step 10, range 0..<30)
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 25) // 20 + 5
    }

    @Test func `3D repeat along Y with step`() async throws {
        let geometry = Box(5).repeated(along: .y, in: 0..<25, step: 8)
        let bounds = try await geometry.bounds

        // Copies at y=0, 8, 16, 24 (step 8, range 0..<25)
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 29) // 24 + 5
    }

    @Test func `2D repeat along X with step`() async throws {
        let geometry = Rectangle(x: 5, y: 3).repeated(along: .x, in: 0..<20, step: 7)
        let bounds = try await geometry.bounds

        // Copies at x=0, 7, 14 (step 7, range 0..<20)
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 19) // 14 + 5
    }

    // MARK: - Repeat with Count (Open Range)

    @Test func `3D repeat along Z with count in open range`() async throws {
        let geometry = Box(5).repeated(along: .z, in: 0..<40, count: 4)
        let bounds = try await geometry.bounds

        // 4 copies evenly distributed in 0..<40, step = 10
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 35) // 30 + 5
    }

    @Test func `2D repeat along Y with count in open range`() async throws {
        let geometry = Circle(diameter: 6).repeated(along: .y, in: 0..<30, count: 3)
        let bounds = try await geometry.bounds

        // 3 copies at y=0, 10, 20
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.y ≈ -3) // radius
        #expect(bounds?.maximum.y ≈ 23) // 20 + radius
    }

    // MARK: - Repeat with Count (Closed Range)

    @Test func `3D repeat along X with count in closed range`() async throws {
        let geometry = Box(5).repeated(along: .x, in: 0...40, count: 5)
        let bounds = try await geometry.bounds

        // 5 copies at x=0, 10, 20, 30, 40 (includes endpoint)
        #expect(try await geometry.partCount == 5)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 45) // 40 + 5
    }

    @Test func `2D repeat along X with count in closed range`() async throws {
        let geometry = Rectangle(x: 4, y: 4).repeated(along: .x, in: 10...30, count: 3)
        let bounds = try await geometry.bounds

        // 3 copies at x=10, 20, 30
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 10)
        #expect(bounds?.maximum.x ≈ 34) // 30 + 4
    }

    // MARK: - Repeat with Step and Count

    @Test func `3D repeat along Y with step and count`() async throws {
        let geometry = Box(5).repeated(along: .y, step: 15, count: 4)
        let bounds = try await geometry.bounds

        // 4 copies at y=0, 15, 30, 45
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 50) // 45 + 5
    }

    @Test func `2D repeat along Y with step and count`() async throws {
        let geometry = Rectangle(x: 3, y: 3).repeated(along: .y, step: 10, count: 3)
        let bounds = try await geometry.bounds

        // 3 copies at y=0, 10, 20
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 23) // 20 + 3
    }

    // MARK: - Repeat with Spacing

    @Test func `3D repeat along X with spacing`() async throws {
        let geometry = Box(x: 10, y: 5, z: 5).repeated(along: .x, spacing: 5, count: 3)
        let bounds = try await geometry.bounds

        // 3 boxes of width 10 with spacing 5: total = 10 + 5 + 10 + 5 + 10 = 40
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 40)
    }

    @Test func `2D repeat along X with spacing`() async throws {
        let geometry = Rectangle(x: 8, y: 4).repeated(along: .x, spacing: 2, count: 4)
        let bounds = try await geometry.bounds

        // 4 rectangles of width 8 with spacing 2: total = 8 + 2 + 8 + 2 + 8 + 2 + 8 = 38
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 38)
    }

    @Test func `repeat with spacing count 1 returns single geometry`() async throws {
        let geometry = Box(10).repeated(along: .x, spacing: 5, count: 1)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 1)
        #expect(bounds?.size.x ≈ 10)
    }

    // MARK: - Repeat with Minimum Spacing

    @Test func `3D repeat with minimum spacing fills range`() async throws {
        // Box of size 5, range 0...50, minimum spacing 3
        // Available: 50-5=45, each slot needs 5+3=8, fits 5 copies (45/8=5.6)
        // But actually the algorithm is different - let me test empirically
        let geometry = Box(5).repeated(along: .x, in: 0...50, minimumSpacing: 3)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 50)
    }

    @Test func `3D repeat with minimum spacing cyclically`() async throws {
        let geometry = Box(5).repeated(along: .x, in: 0...60, minimumSpacing: 5, cyclically: true)
        let bounds = try await geometry.bounds

        // Cyclical: spacing distributed evenly including after last element
        #expect(bounds?.minimum.x ≈ 0)
        // Last element won't be at 60, there's spacing after it
        #expect(bounds!.maximum.x < 60)
    }

    // MARK: - Edge Cases

    @Test func `repeat with count 0 produces empty geometry`() async throws {
        let geometry = Box(5).repeated(along: .x, step: 10, count: 0)
        let bounds = try await geometry.bounds

        #expect(bounds == nil)
    }

    @Test func `repeat single copy`() async throws {
        let geometry = Box(5).repeated(along: .x, step: 10, count: 1)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 1)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 5)
    }
}
