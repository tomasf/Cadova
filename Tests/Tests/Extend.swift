import Foundation
import Testing
@testable import Cadova

struct ExtendTests {
    // MARK: - 3D Extend with Axis Tests

    @Test func `3D geometry extended along Z axis increases height`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(.z, by: 10, at: 10)
            .bounds

        // Original 10x10x20, extended by 10 at z=10
        // Cross-section at z=10 is extruded, top half shifts up
        // Result should be 10x10x30
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 30)
    }

    @Test func `3D geometry extended along X axis increases width`() async throws {
        let bounds = try await Box(x: 20, y: 10, z: 10)
            .extending(.x, by: 5, at: 10)
            .bounds

        // Original 20x10x10, extended by 5 at x=10
        // Result should be 25x10x10
        #expect(bounds?.size.x ≈ 25)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 10)
    }

    @Test func `3D geometry extended along Y axis increases depth`() async throws {
        let bounds = try await Box(x: 10, y: 20, z: 10)
            .extending(.y, by: 8, at: 15)
            .bounds

        // Original 10x20x10, extended by 8 at y=15
        // Result should be 10x28x10
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 28)
        #expect(bounds?.size.z ≈ 10)
    }

    @Test func `3D extend preserves geometry below cut position`() async throws {
        // Cylinder from z=0 to z=30, extended at z=15
        let bounds = try await Cylinder(diameter: 10, height: 30)
            .extending(.z, by: 10, at: 15)
            .bounds

        // Bottom half stays at 0, cross-section at z=15 extruded, top half shifts up by 10
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 40)
        #expect(bounds?.size.z ≈ 40)
    }

    @Test func `3D extend with centered geometry works correctly`() async throws {
        let bounds = try await Box(10)
            .aligned(at: .center)
            .extending(.z, by: 5, at: 0)
            .bounds

        // Box from -5 to 5, extended at z=0
        // Lower half (-5 to 0) stays, cross-section extruded, upper half shifts up
        #expect(bounds?.minimum.z ≈ -5)
        #expect(bounds?.maximum.z ≈ 10)
        #expect(bounds?.size.z ≈ 15)
    }

    // MARK: - 3D Extend with Plane Tests

    @Test func `3D geometry extended along plane`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(at: .z(10), by: 5)
            .bounds

        // Same as axis version but using Plane API
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 25)
    }

    @Test func `3D extend at geometry boundary`() async throws {
        // Extend at z=0, the bottom of the box
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(.z, by: 5, at: 0)
            .bounds

        // Cross-section at z=0 extruded, entire box shifts up by 5
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 25)
        #expect(bounds?.size.z ≈ 25)
    }

    @Test func `3D extend cylinder preserves circular cross-section`() async throws {
        // A cylinder extended should remain cylindrical
        let measurements = try await Cylinder(diameter: 10, height: 20)
            .extending(.z, by: 10, at: 10)
            .measurements

        // Volume of cylinder with diameter 10, height 30
        // Using 1 unit tolerance due to mesh discretization
        let expectedVolume = Double.pi * 5 * 5 * 30
        #expect(measurements.volume.equals(expectedVolume, within: 1))
    }

    // MARK: - Alignment Tests

    @Test func `3D extend with max alignment keeps upper geometry fixed`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(.z, by: 10, at: 10, alignment: .max)
            .bounds

        // Original box from 0-20, extended at z=10 with .max alignment
        // Upper part (10-20) stays fixed, lower part moves down by 10
        #expect(bounds?.minimum.z ≈ -10)
        #expect(bounds?.maximum.z ≈ 20)
        #expect(bounds?.size.z ≈ 30)
    }

    @Test func `3D extend with mid alignment centers the extension`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(.z, by: 10, at: 10, alignment: .mid)
            .bounds

        // Original box from 0-20, extended at z=10 with .mid alignment
        // Lower part moves down by 5, upper part moves up by 5
        #expect(bounds?.minimum.z ≈ -5)
        #expect(bounds?.maximum.z ≈ 25)
        #expect(bounds?.size.z ≈ 30)
    }

    @Test func `3D extend with min alignment keeps lower geometry fixed`() async throws {
        let bounds = try await Box(x: 10, y: 10, z: 20)
            .extending(.z, by: 10, at: 10, alignment: .min)
            .bounds

        // Original box from 0-20, extended at z=10 with .min alignment (default)
        // Lower part (0-10) stays fixed, upper part moves up by 10
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 30)
        #expect(bounds?.size.z ≈ 30)
    }

    @Test func `3D extend with plane and alignment`() async throws {
        let bounds = try await Cylinder(diameter: 10, height: 30)
            .extending(at: .z(15), by: 10, alignment: .max)
            .bounds

        // Cylinder from 0-30, extended at z=15 with .max alignment
        // Upper part stays at 30, lower part moves down by 10
        #expect(bounds?.minimum.z ≈ -10)
        #expect(bounds?.maximum.z ≈ 30)
        #expect(bounds?.size.z ≈ 40)
    }
}
