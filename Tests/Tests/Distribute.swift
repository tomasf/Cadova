import Foundation
import Testing
@testable import Cadova

struct DistributeTests {
    // MARK: - Distribute Along Axis

    @Test func `3D distribute along X axis`() async throws {
        let geometry = Box(5).distributed(at: [0, 10, 20], along: .x)
        let bounds = try await geometry.bounds

        // Three 5x5x5 boxes at x=0, x=10, x=20
        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 25) // 20 + 5
        #expect(bounds?.size.y ≈ 5)
        #expect(bounds?.size.z ≈ 5)
    }

    @Test func `3D distribute along Y axis`() async throws {
        let geometry = Box(5).distributed(at: [0, 15, 30], along: .y)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 35) // 30 + 5
    }

    @Test func `3D distribute along Z axis`() async throws {
        let geometry = Box(5).distributed(at: [0, 10], along: .z)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 15) // 10 + 5
    }

    @Test func `3D distribute with stride`() async throws {
        let geometry = Cylinder(diameter: 2, height: 10)
            .distributed(at: stride(from: 0.0, through: 20.0, by: 5.0), along: .x)
        let bounds = try await geometry.bounds

        // 5 cylinders at x=0, 5, 10, 15, 20
        #expect(try await geometry.partCount == 5)
        #expect(bounds!.minimum.x.equals(-1, within: 0.1)) // radius (approximate due to mesh)
        #expect(bounds!.maximum.x.equals(21, within: 0.1)) // 20 + radius
    }

    @Test func `2D distribute along X axis`() async throws {
        let geometry = Circle(diameter: 10).distributed(at: [0, 20, 40], along: .x)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ -5) // radius
        #expect(bounds?.maximum.x ≈ 45) // 40 + radius
    }

    @Test func `2D distribute along Y axis`() async throws {
        let geometry = Rectangle(x: 5, y: 3).distributed(at: [0, 10], along: .y)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 13) // 10 + 3
    }

    // MARK: - Distribute at Vector Offsets

    @Test func `3D distribute at vector offsets`() async throws {
        let geometry = Box(5).distributed(at: [
            Vector3D(0, 0, 0),
            Vector3D(10, 10, 0),
            Vector3D(20, 0, 10)
        ])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 25)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 15)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 15)
    }

    @Test func `2D distribute at vector offsets`() async throws {
        let geometry = Rectangle(x: 5, y: 5).distributed(at: [
            Vector2D(0, 0),
            Vector2D(10, 10),
            Vector2D(20, 5)
        ])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 3)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 25)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 15)
    }

    @Test func `3D distribute at variadic vector offsets`() async throws {
        let geometry = Box(5).distributed(at: [0, 0, 0], [15, 0, 0])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 20)
    }

    // MARK: - Distribute at Transforms

    @Test func `3D distribute at transforms`() async throws {
        let geometry = Box(5).distributed(at: [
            Transform3D.identity,
            Transform3D.translation(x: 10).rotated(z: 45°)
        ])
        let bounds = try await geometry.bounds

        // First box at origin, second at x=10 rotated 45°
        #expect(try await geometry.partCount == 2)
        #expect(bounds != nil)
        #expect(bounds!.maximum.x > 10)
    }

    @Test func `2D distribute at transforms`() async throws {
        let geometry = Rectangle(x: 10, y: 5).distributed(at: [
            Transform2D.identity,
            Transform2D.translation(x: 20)
        ])
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 30)
    }

    // MARK: - Distribute at Angles

    @Test func `2D distribute at angles`() async throws {
        let geometry = Rectangle(x: 10, y: 2)
            .translated(x: 5)
            .distributed(at: [0°, 90°, 180°, 270°])
        let bounds = try await geometry.bounds

        // Four rectangles forming a cross pattern
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -15)
        #expect(bounds?.maximum.y ≈ 15)
    }

    @Test func `3D distribute at angles around Z axis`() async throws {
        let geometry = Box(x: 10, y: 2, z: 3)
            .translated(x: 5)
            .distributed(at: [0°, 90°, 180°, 270°], around: .z)
        let bounds = try await geometry.bounds

        // Four boxes forming a cross pattern around Z
        #expect(try await geometry.partCount == 4)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ -15)
        #expect(bounds?.maximum.y ≈ 15)
        #expect(bounds?.size.z ≈ 3)
    }

    @Test func `3D distribute at angles around Y axis`() async throws {
        let geometry = Box(x: 10, y: 2, z: 3)
            .translated(x: 5)
            .distributed(at: [0°, 180°], around: .y)
        let bounds = try await geometry.bounds

        // Two boxes mirrored around Y axis
        #expect(try await geometry.partCount == 2)
        #expect(bounds?.minimum.x ≈ -15)
        #expect(bounds?.maximum.x ≈ 15)
    }

    // MARK: - Edge Cases

    @Test func `distribute with single offset returns translated copy`() async throws {
        let geometry = Box(5).distributed(at: [10], along: .x)
        let bounds = try await geometry.bounds

        #expect(try await geometry.partCount == 1)
        #expect(bounds?.minimum.x ≈ 10)
        #expect(bounds?.maximum.x ≈ 15)
    }

}
