import Foundation
import Testing
@testable import Cadova

struct CloneTests {
    // MARK: - Generic Clone Tests

    @Test func `cloned with transform creates two geometries`() async throws {
        let bounds = try await Rectangle(x: 10, y: 10)
            .cloned { $0.translated(x: 20) }
            .bounds

        // Should span from 0 to 30 (original 0-10, clone 20-30)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 30)
        #expect(bounds?.size.y ≈ 10)
    }

    @Test func `cloned with rotation creates rotated copy`() async throws {
        let bounds = try await Rectangle(x: 20, y: 10)
            .aligned(at: .center)
            .cloned { $0.rotated(90°) }
            .bounds

        // Original is 20x10 centered, rotated clone is 10x20 centered
        // Combined bounds should be 20x20 centered at origin
        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 20)
    }

    // MARK: - 2D Clone Tests

    @Test func `2D clonedAt creates translated copy`() async throws {
        let bounds = try await Circle(diameter: 10)
            .clonedAt(x: 20)
            .bounds

        // Original circle centered at origin (-5 to 5), clone at x=20 (15 to 25)
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 25)
    }

    @Test func `2D clonedAt with y offset`() async throws {
        let bounds = try await Rectangle(x: 10, y: 10)
            .clonedAt(y: 15)
            .bounds

        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 25)
    }

    @Test func `2D cloned at vector offset`() async throws {
        let bounds = try await Rectangle(x: 5, y: 5)
            .cloned(at: Vector2D(10, 10))
            .bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 15)
    }

    // MARK: - 3D Clone Tests

    @Test func `3D clonedAt creates translated copy`() async throws {
        let bounds = try await Box(10)
            .clonedAt(x: 20)
            .bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 30)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 10)
    }

    @Test func `3D clonedAt with z offset`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 10)
            .clonedAt(z: 15)
            .bounds

        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 25)
    }

    @Test func `3D cloned at vector offset`() async throws {
        let bounds = try await Box(5)
            .cloned(at: Vector3D(10, 10, 10))
            .bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 15)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 15)
    }

    @Test func `multiple clones can be chained`() async throws {
        let bounds = try await Box(10)
            .clonedAt(x: 15)
            .clonedAt(y: 15)
            .bounds

        // After first clone: 0-10 and 15-25 in X
        // After second clone: duplicates both in Y at +15
        #expect(bounds?.size.x ≈ 25)
        #expect(bounds?.size.y ≈ 25)
    }
}
