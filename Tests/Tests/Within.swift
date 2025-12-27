import Foundation
import Testing
@testable import Cadova

struct WithinTests {
    // MARK: - 2D Clipping

    @Test func `2D within clips to X range`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(x: 5..<15)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.size.y ≈ 10) // Y unchanged
    }

    @Test func `2D within clips to Y range`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(y: 2..<8)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ 2)
        #expect(bounds?.maximum.y ≈ 8)
        #expect(bounds?.size.x ≈ 20) // X unchanged
    }

    @Test func `2D within clips to both axes`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(x: 5..<15, y: 2..<8)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 2)
        #expect(bounds?.maximum.y ≈ 8)
    }

    @Test func `2D within with partial range from`() async throws {
        // Circle centered at origin, clip to y >= 0 (upper half)
        let geometry = Circle(diameter: 10)
            .aligned(at: .center)
            .within(y: 0.0...)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 5)
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
    }

    @Test func `2D within with partial range through`() async throws {
        // Circle centered at origin, clip to y <= 0 (lower half)
        let geometry = Circle(diameter: 10)
            .aligned(at: .center)
            .within(y: ...0.0)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ -5)
        #expect(bounds?.maximum.y ≈ 0)
    }

    @Test func `2D within with closed range`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(x: 5...15)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
    }

    // MARK: - 3D Clipping

    @Test func `3D within clips to X range`() async throws {
        let geometry = Box(x: 20, y: 10, z: 5)
            .within(x: 5..<15)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 5)
    }

    @Test func `3D within clips to Z range`() async throws {
        let geometry = Box(x: 20, y: 10, z: 10)
            .within(z: 2..<8)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.z ≈ 2)
        #expect(bounds?.maximum.z ≈ 8)
    }

    @Test func `3D within clips to multiple axes`() async throws {
        let geometry = Box(x: 20, y: 20, z: 20)
            .within(x: 5..<15, y: 5..<15, z: 5..<15)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 5)
        #expect(bounds?.maximum.y ≈ 15)
        #expect(bounds?.minimum.z ≈ 5)
        #expect(bounds?.maximum.z ≈ 15)
    }

    @Test func `3D within with partial range creates hemisphere`() async throws {
        // Sphere centered at origin, clip to z >= 0 (upper hemisphere)
        let geometry = Sphere(diameter: 10)
            .aligned(at: .center)
            .within(z: 0.0...)
        let bounds = try await geometry.bounds

        #expect(bounds!.minimum.z.equals(0, within: 0.1))
        #expect(bounds!.maximum.z.equals(5, within: 0.1))
    }

    @Test func `3D within with partial range through`() async throws {
        // Sphere centered at origin, clip to z <= 0 (lower hemisphere)
        let geometry = Sphere(diameter: 10)
            .aligned(at: .center)
            .within(z: ...0.0)
        let bounds = try await geometry.bounds

        #expect(bounds!.minimum.z.equals(-5, within: 0.1))
        #expect(bounds!.maximum.z.equals(0, within: 0.1))
    }

    // MARK: - 2D Within with Operations

    @Test func `2D within do applies operation to region`() async throws {
        // Rectangle, translate only the right half
        let geometry = Rectangle(x: 20, y: 10)
            .within(x: 10.0...) {
                $0.translated(y: 5)
            }
        let bounds = try await geometry.bounds

        // Left half stays at y: 0-10, right half moves to y: 5-15
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 20)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 15)
    }

    @Test func `2D within do preserves geometry outside region`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(x: 10.0...) {
                $0.translated(x: 10)
            }
        let bounds = try await geometry.bounds

        // Left half at x: 0-10, right half moves to x: 20-30
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 30)
        #expect(try await geometry.partCount == 2) // Two separate parts now
    }

    @Test func `2D within do with scaling`() async throws {
        let geometry = Rectangle(x: 20, y: 10)
            .within(y: 5.0...) {
                $0.scaled(x: 0.5)
            }
        let bounds = try await geometry.bounds

        // Lower half full width, upper half scaled to half width
        #expect(bounds?.size.x ≈ 20) // Lower half still 20 wide
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 10)
    }

    // MARK: - 3D Within with Operations

    @Test func `3D within do applies operation to region`() async throws {
        // Box, translate only the top half
        let geometry = Box(x: 10, y: 10, z: 20)
            .within(z: 10.0...) {
                $0.translated(z: 5)
            }
        let bounds = try await geometry.bounds

        // Bottom half at z: 0-10, top half moves to z: 15-25
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 25)
    }

    @Test func `3D within do preserves geometry outside region`() async throws {
        let geometry = Box(x: 10, y: 10, z: 20)
            .within(z: 10.0...) {
                $0.translated(z: 10)
            }
        let bounds = try await geometry.bounds

        // Bottom at z: 0-10, top moves to z: 20-30
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 30)
        #expect(try await geometry.partCount == 2)
    }

    @Test func `3D within do with rotation`() async throws {
        let geometry = Box(x: 20, y: 10, z: 10)
            .within(x: 10.0...) {
                $0.rotated(z: 45°)
            }
        let bounds = try await geometry.bounds

        // Right half rotated, should extend beyond original bounds
        #expect(bounds != nil)
        #expect(bounds!.maximum.y > 10)
    }

    // MARK: - Edge Cases

    @Test func `within with nil ranges returns original`() async throws {
        let original = Box(x: 10, y: 10, z: 10)
        let clipped = original.within(x: nil, y: nil, z: nil)

        let originalBounds = try await original.bounds
        let clippedBounds = try await clipped.bounds

        #expect(originalBounds?.minimum.x ≈ clippedBounds?.minimum.x)
        #expect(originalBounds?.maximum.x ≈ clippedBounds?.maximum.x)
    }

    @Test func `within range outside geometry returns empty`() async throws {
        let geometry = Box(10).within(x: 100..<200)
        let bounds = try await geometry.bounds

        #expect(bounds == nil)
    }

    @Test func `within range partially overlapping`() async throws {
        // Box from 0-10, clip to 5-15 (only overlaps 5-10)
        let geometry = Box(10).within(x: 5..<15)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 10)
    }
}
