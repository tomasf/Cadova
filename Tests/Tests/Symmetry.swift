import Foundation
import Testing
@testable import Cadova

struct SymmetryTests {
    // MARK: - 2D Symmetry Tests

    @Test func `2D symmetry over X axis creates two copies`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 5, y: 2.5)
            .symmetry(over: .x)
        let bounds = try await geometry.bounds

        // Original at x: 5-15, mirrored copy at x: -15 to -5
        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.size.y ≈ 5)
    }

    @Test func `2D symmetry over Y axis creates two copies`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 5, y: 2.5)
            .symmetry(over: .y)
        let bounds = try await geometry.bounds

        // Original at y: 2.5-7.5, mirrored copy at y: -7.5 to -2.5
        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.y ≈ -7.5)
        #expect(bounds?.maximum.y ≈ 7.5)
        #expect(bounds?.size.x ≈ 10)
    }

    @Test func `2D symmetry over both axes creates four copies`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 5, y: 2.5)
            .symmetry(over: [.x, .y])
        let bounds = try await geometry.bounds

        // Should span from -15 to 15 in X and -7.5 to 7.5 in Y
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -7.5)
        #expect(bounds?.maximum.y ≈ 7.5)
    }

    @Test func `2D symmetry with empty axes returns original`() async throws {
        let original = Rectangle(x: 10, y: 5).translated(x: 5, y: 2.5)
        let symmetric = original.symmetry(over: [])
        let originalBounds = try await original.bounds
        let symmetricBounds = try await symmetric.bounds

        #expect(try await symmetric.partCount == 1)
        #expect(originalBounds?.minimum.x ≈ symmetricBounds?.minimum.x)
        #expect(originalBounds?.maximum.x ≈ symmetricBounds?.maximum.x)
    }

    // MARK: - 3D Symmetry Tests

    @Test func `3D symmetry over X axis creates two copies`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 5)
            .symmetry(over: .x)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.size.y ≈ 5)
        #expect(bounds?.size.z ≈ 3)
    }

    @Test func `3D symmetry over Y axis creates two copies`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(y: 2.5)
            .symmetry(over: .y)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.y ≈ -7.5)
        #expect(bounds?.maximum.y ≈ 7.5)
    }

    @Test func `3D symmetry over Z axis creates two copies`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(z: 1.5)
            .symmetry(over: .z)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.z ≈ -4.5)
        #expect(bounds?.maximum.z ≈ 4.5)
    }

    @Test func `3D symmetry over XY creates four copies`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 5, y: 2.5)
            .symmetry(over: [.x, .y])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -7.5)
        #expect(bounds?.maximum.y ≈ 7.5)
        #expect(bounds?.size.z ≈ 3)
    }

    @Test func `3D symmetry over all axes creates eight copies`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 5, y: 2.5, z: 1.5)
            .symmetry(over: [.x, .y, .z])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 8)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -7.5)
        #expect(bounds?.maximum.y ≈ 7.5)
        #expect(bounds?.minimum.z ≈ -4.5)
        #expect(bounds?.maximum.z ≈ 4.5)
    }

    @Test func `3D symmetry with empty axes returns original`() async throws {
        let original = Box(x: 10, y: 5, z: 3).translated(x: 5)
        let symmetric = original.symmetry(over: [])
        let originalBounds = try await original.bounds
        let symmetricBounds = try await symmetric.bounds

        #expect(try await symmetric.partCount == 1)
        #expect(originalBounds?.minimum.x ≈ symmetricBounds?.minimum.x)
        #expect(originalBounds?.maximum.x ≈ symmetricBounds?.maximum.x)
    }
}
