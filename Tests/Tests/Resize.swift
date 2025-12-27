import Foundation
import Testing
@testable import Cadova

struct ResizeTests {
    // MARK: - 2D Resize Tests

    @Test func `2D geometry can be resized to specific dimensions`() async throws {
        let bounds = try await Rectangle(x: 10, y: 20)
            .resized(x: 30, y: 40)
            .bounds

        #expect(bounds?.size.x ≈ 30)
        #expect(bounds?.size.y ≈ 40)
    }

    @Test func `2D resize with proportional Y scales proportionally`() async throws {
        // Start with 10x20, resize X to 20 (2x), Y should become 40 (2x)
        let bounds = try await Rectangle(x: 10, y: 20)
            .resized(x: 20, y: .proportional)
            .bounds

        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 40)
    }

    @Test func `2D resize with fixed Y keeps Y unchanged`() async throws {
        let bounds = try await Rectangle(x: 10, y: 20)
            .resized(x: 30, y: .fixed)
            .bounds

        #expect(bounds?.size.x ≈ 30)
        #expect(bounds?.size.y ≈ 20)
    }

    @Test func `2D resize with proportional X scales proportionally`() async throws {
        // Start with 10x20, resize Y to 40 (2x), X should become 20 (2x)
        let bounds = try await Rectangle(x: 10, y: 20)
            .resized(x: .proportional, y: 40)
            .bounds

        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 40)
    }

    @Test func `2D resize with center alignment keeps center position`() async throws {
        let original = Rectangle(x: 10, y: 20).aligned(at: .center)
        let originalBounds = try await original.bounds

        let resized = original.resized(x: 20, y: 40, alignment: .center)
        let resizedBounds = try await resized.bounds

        #expect(originalBounds?.center.x ≈ resizedBounds?.center.x)
        #expect(originalBounds?.center.y ≈ resizedBounds?.center.y)
    }

    // MARK: - 3D Resize Tests

    @Test func `3D geometry can be resized to specific dimensions`() async throws {
        let bounds = try await Box(x: 10, y: 20, z: 30)
            .resized(x: 5, y: 10, z: 15)
            .bounds

        #expect(bounds?.size.x ≈ 5)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 15)
    }

    @Test func `3D resize X with proportional Y and Z`() async throws {
        // Start with 10x20x30, resize X to 20 (2x), Y and Z should double
        let bounds = try await Box(x: 10, y: 20, z: 30)
            .resized(x: 20, y: .proportional, z: .proportional)
            .bounds

        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 40)
        #expect(bounds?.size.z ≈ 60)
    }

    @Test func `3D resize Y with fixed X and proportional Z`() async throws {
        // Start with 10x20x40, resize Y to 40 (2x), X fixed, Z proportional
        let bounds = try await Box(x: 10, y: 20, z: 40)
            .resized(x: .fixed, y: 40, z: .proportional)
            .bounds

        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 40)
        #expect(bounds?.size.z ≈ 80)
    }

    @Test func `3D resize Z with proportional X and Y`() async throws {
        // Start with 10x20x30, resize Z to 60 (2x), X and Y should double
        let bounds = try await Box(x: 10, y: 20, z: 30)
            .resized(x: .proportional, y: .proportional, z: 60)
            .bounds

        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 40)
        #expect(bounds?.size.z ≈ 60)
    }

    @Test func `3D resize with center alignment keeps center position`() async throws {
        let original = Box(x: 10, y: 20, z: 30).aligned(at: .center)
        let originalBounds = try await original.bounds

        let resized = original.resized(x: 20, y: 40, z: 60, alignment: .center)
        let resizedBounds = try await resized.bounds

        #expect(originalBounds?.center.x ≈ resizedBounds?.center.x)
        #expect(originalBounds?.center.y ≈ resizedBounds?.center.y)
        #expect(originalBounds?.center.z ≈ resizedBounds?.center.z)
    }

    @Test func `3D resize with calculator closure`() async throws {
        // Double each dimension using a calculator
        let bounds = try await Box(x: 10, y: 20, z: 30)
            .resized { $0 * 2 }
            .bounds

        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 40)
        #expect(bounds?.size.z ≈ 60)
    }
}
