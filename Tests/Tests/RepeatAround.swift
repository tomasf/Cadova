import Foundation
import Testing
@testable import Cadova

struct RepeatAroundTests {
    // MARK: - 2D Repeat with Step

    @Test func `2D repeat full circle with step`() async throws {
        let geometry = Rectangle(x: 5, y: 2)
            .translated(x: 10)
            .repeated(step: 90°)
        let bounds = try await geometry.bounds

        // 4 copies at 0°, 90°, 180°, 270°
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -15)
        #expect(bounds?.maximum.y ≈ 15)
    }

    @Test func `2D repeat partial arc with step`() async throws {
        let geometry = Rectangle(x: 5, y: 2)
            .translated(x: 10)
            .repeated(in: 0°..<180°, step: 45°)
        let bounds = try await geometry.bounds

        // Copies at 0°, 45°, 90°, 135° (not including 180°)
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.maximum.y ≈ 15) // 90° rotation puts it at y=10+5
    }

    // MARK: - 2D Repeat with Count (Open Range)

    @Test func `2D repeat full circle with count`() async throws {
        let geometry = Circle(diameter: 4)
            .translated(x: 15)
            .repeated(count: 6)
        let bounds = try await geometry.bounds

        // 6 copies evenly distributed around full circle
        #expect(try await geometry.partCount == 6)
        #expect(bounds?.minimum.x ≈ -17) // 15 + radius
        #expect(bounds?.maximum.x ≈ 17)
    }

    @Test func `2D repeat partial arc with count`() async throws {
        let geometry = Rectangle(x: 4, y: 2)
            .translated(x: 10)
            .repeated(in: 0°..<90°, count: 3)

        // 3 copies at 0°, 30°, 60°
        #expect(try await geometry.partCount == 3)
    }

    // MARK: - 2D Repeat with Count (Closed Range)

    @Test func `2D repeat in closed range with count`() async throws {
        let geometry = Rectangle(x: 4, y: 2)
            .translated(x: 10)
            .repeated(in: 0°...90°, count: 3)

        // 3 copies at 0°, 45°, 90° (includes endpoint)
        #expect(try await geometry.partCount == 3)
    }

    // MARK: - 3D Repeat Around Z Axis

    @Test func `3D repeat around Z with step`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .z, step: 60°)
        let bounds = try await geometry.bounds

        // 6 copies at 0°, 60°, 120°, 180°, 240°, 300°
        #expect(try await geometry.partCount == 6)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.size.z ≈ 3)
    }

    @Test func `3D repeat around Z with count`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .z, count: 8)

        // 8 copies evenly distributed
        #expect(try await geometry.partCount == 8)
    }

    @Test func `3D repeat around Z partial arc`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .z, in: 0°..<180°, count: 4)
        let bounds = try await geometry.bounds

        // 4 copies in upper half (0°, 45°, 90°, 135°)
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.maximum.y ≈ 15) // 90° rotation puts it at y=10+5
    }

    // MARK: - 3D Repeat Around Y Axis

    @Test func `3D repeat around Y with step`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .y, step: 90°)
        let bounds = try await geometry.bounds

        // 4 copies around Y axis
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.z ≈ -15)
        #expect(bounds?.maximum.z ≈ 15)
        #expect(bounds?.size.y ≈ 2)
    }

    @Test func `3D repeat around Y with count`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .y, count: 3)

        // 3 copies at 0°, 120°, 240°
        #expect(try await geometry.partCount == 3)
    }

    // MARK: - 3D Repeat Around X Axis

    @Test func `3D repeat around X with step`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(y: 10)
            .repeated(around: .x, step: 120°)
        let bounds = try await geometry.bounds

        // 3 copies around X axis
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.size.x ≈ 5)
    }

    // MARK: - 3D Repeat with Closed Range

    @Test func `3D repeat around Z in closed range`() async throws {
        let geometry = Box(x: 5, y: 2, z: 3)
            .translated(x: 10)
            .repeated(around: .z, in: 0°...180°, count: 5)

        // 5 copies at 0°, 45°, 90°, 135°, 180°
        #expect(try await geometry.partCount == 5)
    }

    // MARK: - Edge Cases

    @Test func `repeat around with count 0 produces empty geometry`() async throws {
        let geometry = Box(5).translated(x: 10).repeated(around: .z, count: 0)
        let bounds = try await geometry.bounds

        #expect(bounds == nil)
    }

    @Test func `repeat around with count 1 produces single copy`() async throws {
        let geometry = Box(5).translated(x: 10).repeated(around: .z, count: 1)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 1)
        #expect(bounds?.minimum.x ≈ 10)
        #expect(bounds?.maximum.x ≈ 15)
    }
}
