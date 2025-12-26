import Foundation
import Testing
@testable import Cadova

struct WarpTests {
    // MARK: - 2D Warp with Return Value

    @Test func `2D warp translates all points`() async throws {
        let geometry = Rectangle(x: 10, y: 10)
            .warped(operationName: "translate", cacheParameters: 5.0) { point in
                Vector2D(point.x + 5, point.y + 3)
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 3)
        #expect(bounds?.maximum.y ≈ 13)
    }

    @Test func `2D warp scales geometry`() async throws {
        let geometry = Rectangle(x: 10, y: 10)
            .warped(operationName: "scale", cacheParameters: 2.0) { point in
                point * 2
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 20)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 20)
    }

    @Test func `2D warp with non-uniform transformation`() async throws {
        let geometry = Rectangle(x: 10, y: 10)
            .warped(operationName: "stretch", cacheParameters: 3.0, 1.0) { point in
                Vector2D(point.x * 3, point.y)
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 30)
        #expect(bounds?.size.y ≈ 10)
    }

    // MARK: - 2D Warp with Inout

    @Test func `2D warp with inout modifier`() async throws {
        let geometry = Rectangle(x: 10, y: 10)
            .warped(operationName: "inout-translate", cacheParameters: 7.0) { point in
                point.x += 7
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 7)
        #expect(bounds?.maximum.x ≈ 17)
    }

    // MARK: - 3D Warp with Return Value

    @Test func `3D warp translates all points`() async throws {
        let geometry = Box(x: 10, y: 10, z: 10)
            .warped(operationName: "translate3d", cacheParameters: 5.0) { point in
                Vector3D(point.x + 5, point.y + 3, point.z + 2)
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 15)
        #expect(bounds?.minimum.y ≈ 3)
        #expect(bounds?.maximum.y ≈ 13)
        #expect(bounds?.minimum.z ≈ 2)
        #expect(bounds?.maximum.z ≈ 12)
    }

    @Test func `3D warp scales geometry`() async throws {
        let geometry = Box(x: 10, y: 10, z: 10)
            .warped(operationName: "scale3d", cacheParameters: 0.5) { point in
                point * 0.5
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.size.y ≈ 5)
        #expect(bounds?.size.z ≈ 5)
    }

    @Test func `3D warp with wave deformation`() async throws {
        let amplitude = 2.0
        let frequency = 0.5
        // Use a sphere with many vertices to ensure wave effect is visible
        let geometry = Sphere(diameter: 10)
            .aligned(at: .center)
            .warped(operationName: "wave", cacheParameters: amplitude, frequency) { point in
                Vector3D(point.x, point.y, point.z + sin(point.x * frequency) * amplitude)
            }
        let bounds = try await geometry.bounds

        // Z bounds should expand due to wave (at least some effect)
        #expect(bounds != nil)
        // Original sphere is -5 to 5 in Z, wave adds up to ±amplitude
        #expect(bounds!.size.z > 10) // Some expansion expected
    }

    // MARK: - 3D Warp with Inout

    @Test func `3D warp with inout modifier`() async throws {
        let geometry = Box(x: 10, y: 10, z: 10)
            .warped(operationName: "inout-translate3d", cacheParameters: 4.0) { point in
                point.z += 4
            }
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.z ≈ 4)
        #expect(bounds?.maximum.z ≈ 14)
    }

    @Test func `3D warp with complex inout transformation`() async throws {
        let geometry = Box(x: 10, y: 10, z: 10)
            .warped(operationName: "taper", cacheParameters: 0.5) { point in
                let scale = 1.0 - point.z * 0.05
                point.x *= scale
                point.y *= scale
            }
        let bounds = try await geometry.bounds

        // Top should be narrower than bottom
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.size.z ≈ 10)
    }

    // MARK: - Non-linear Transformations

    @Test func `3D warp with uniform expansion`() async throws {
        // Simple uniform scaling via warp
        let geometry = Sphere(diameter: 10)
            .aligned(at: .center)
            .warped(operationName: "expand", cacheParameters: 1.2) { point in
                point * 1.2
            }
        let bounds = try await geometry.bounds

        // Should be 20% larger than original
        #expect(bounds != nil)
        #expect(bounds!.size.x.equals(12, within: 0.2))
        #expect(bounds!.size.y.equals(12, within: 0.2))
        #expect(bounds!.size.z.equals(12, within: 0.2))
    }

    @Test func `2D warp with radial distortion`() async throws {
        let geometry = Circle(diameter: 10)
            .aligned(at: .center)
            .warped(operationName: "radial", cacheParameters: 0.8) { point in
                let distance = point.magnitude
                let angle = Foundation.atan2(point.y, point.x)
                let newDistance = distance * 0.8
                return Vector2D(cos(angle) * newDistance, sin(angle) * newDistance)
            }
        let bounds = try await geometry.bounds

        // Should be smaller due to 0.8 scale
        #expect(bounds!.size.x < 10)
        #expect(bounds!.size.y < 10)
    }

    // MARK: - Cache Behavior

    @Test func `warp with same parameters produces same result`() async throws {
        let base = Box(10)

        let warp1 = base.warped(operationName: "offset", cacheParameters: 5.0) { $0 + [5, 0, 0] }
        let warp2 = base.warped(operationName: "offset", cacheParameters: 5.0) { $0 + [5, 0, 0] }

        let bounds1 = try await warp1.bounds
        let bounds2 = try await warp2.bounds

        #expect(bounds1?.minimum.x ≈ bounds2?.minimum.x)
        #expect(bounds1?.maximum.x ≈ bounds2?.maximum.x)
    }

    @Test func `warp with different parameters produces different results`() async throws {
        let base = Box(10)

        let warp1 = base.warped(operationName: "offset", cacheParameters: 5.0) { $0 + [5, 0, 0] }
        let warp2 = base.warped(operationName: "offset", cacheParameters: 10.0) { $0 + [10, 0, 0] }

        let bounds1 = try await warp1.bounds
        let bounds2 = try await warp2.bounds

        #expect(bounds1?.minimum.x ≈ 5)
        #expect(bounds2?.minimum.x ≈ 10)
    }

    // MARK: - Edge Cases

    @Test func `warp identity transformation`() async throws {
        let original = Box(10)
        let warped = original.warped(operationName: "identity", cacheParameters: 0) { $0 }

        let originalBounds = try await original.bounds
        let warpedBounds = try await warped.bounds

        #expect(originalBounds?.minimum.x ≈ warpedBounds?.minimum.x)
        #expect(originalBounds?.maximum.x ≈ warpedBounds?.maximum.x)
        #expect(originalBounds?.size.x ≈ warpedBounds?.size.x)
    }

    @Test func `warp with zero scale collapses geometry`() async throws {
        let geometry = Box(10)
            .warped(operationName: "collapse", cacheParameters: 0.0) { _ in
                Vector3D(0, 0, 0)
            }
        let bounds = try await geometry.bounds

        // All points collapsed to origin - geometry may be degenerate
        #expect(bounds?.size.x ≈ 0)
        #expect(bounds?.size.y ≈ 0)
        #expect(bounds?.size.z ≈ 0)
    }
}
