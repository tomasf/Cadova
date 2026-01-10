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

    // MARK: - 3D Resize Tests

    @Test func `3D resizing stretches a range`() async throws {
        // Box 10x10x30, resize z range 10...20 (length 10) to length 20
        let bounds = try await Box(x: 10, y: 10, z: 30)
            .resizing(.z, in: 10...20, to: 20)
            .bounds

        // Original height 30, range stretched by 10, new height 40
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 40)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 40)
    }

    @Test func `3D resizing compresses a range`() async throws {
        // Box 10x10x30, resize z range 10...20 (length 10) to length 5
        let bounds = try await Box(x: 10, y: 10, z: 30)
            .resizing(.z, in: 10...20, to: 5)
            .bounds

        // Original height 30, range compressed by 5, new height 25
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 25)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 25)
    }

    @Test func `3D resizing preserves volume proportionally`() async throws {
        // Cylinder diameter 10, height 30
        // Resize z range 10...20 to 15 (1.5x stretch)
        let original = Cylinder(diameter: 10, height: 30)
        let resized = original.resizing(.z, in: 10...20, to: 15)

        let originalVolume = try await original.measurements.volume
        let resizedVolume = try await resized.measurements.volume

        // Original: pi * 5^2 * 30
        // Resized: height becomes 35 (30 + 5), but only the middle 10 units got scaled
        // The middle section volume scales by 1.5x
        // Original middle section: pi * 25 * 10
        // New middle section: pi * 25 * 15
        // Total change: pi * 25 * 5 = ~392.7
        let expectedVolumeIncrease = Double.pi * 25 * 5
        #expect((resizedVolume - originalVolume).equals(expectedVolumeIncrease, within: 5))
    }

    @Test func `3D resizing to zero removes the range`() async throws {
        // Box 10x10x30, resize z range 10...20 to 0
        let bounds = try await Box(x: 10, y: 10, z: 30)
            .resizing(.z, in: 10...20, to: 0)
            .bounds

        // Original height 30, range removed (10 units), new height 20
        #expect(bounds?.size.z ≈ 20)
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 20)
    }

    @Test func `3D resizing with max alignment keeps upper geometry fixed`() async throws {
        // Box 10x10x30, resize z range 10...20 to 15 with .max alignment
        let bounds = try await Box(x: 10, y: 10, z: 30)
            .resizing(.z, in: 10...20, to: 15, alignment: .max)
            .bounds

        // Upper part (20-30) stays at z=30
        // Range expands downward by 5
        #expect(bounds?.maximum.z ≈ 30)
        #expect(bounds?.minimum.z ≈ -5)
        #expect(bounds?.size.z ≈ 35)
    }

    @Test func `3D resizing with mid alignment centers the change`() async throws {
        // Box 10x10x30, resize z range 10...20 to 20 with .mid alignment
        let bounds = try await Box(x: 10, y: 10, z: 30)
            .resizing(.z, in: 10...20, to: 20, alignment: .mid)
            .bounds

        // Range center at z=15 stays fixed
        // Lower part moves down by 5, upper part moves up by 5
        #expect(bounds?.minimum.z ≈ -5)
        #expect(bounds?.maximum.z ≈ 35)
        #expect(bounds?.size.z ≈ 40)
    }

    @Test func `3D resizing along X axis`() async throws {
        let bounds = try await Box(x: 30, y: 10, z: 10)
            .resizing(.x, in: 10...20, to: 5)
            .bounds

        // Original width 30, range compressed by 5, new width 25
        #expect(bounds?.size.x ≈ 25)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 10)
    }

    @Test func `3D resizing along Y axis`() async throws {
        let bounds = try await Box(x: 10, y: 30, z: 10)
            .resizing(.y, in: 5...15, to: 20)
            .bounds

        // Original depth 30, range stretched by 10, new depth 40
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 40)
        #expect(bounds?.size.z ≈ 10)
    }

    @Test func `3D resizing cylinder preserves circular cross-section`() async throws {
        // Cylinder resized should remain cylindrical in cross-section
        let measurements = try await Cylinder(diameter: 10, height: 30)
            .resizing(.z, in: 10...20, to: 5)
            .measurements

        // Height goes from 30 to 25
        // Volume = pi * r^2 * h = pi * 25 * 25
        let expectedVolume = Double.pi * 25 * 25
        #expect(measurements.volume.equals(expectedVolume, within: 1))
    }

    // MARK: - 2D Resize Tests

    @Test func `2D resizing stretches a range along X`() async throws {
        // Rectangle 30x10, resize x range 10...20 (length 10) to length 20
        let bounds = try await Rectangle(x: 30, y: 10)
            .resizing(.x, in: 10...20, to: 20)
            .bounds

        // Original width 30, range stretched by 10, new width 40
        #expect(bounds?.size.x ≈ 40)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 40)
    }

    @Test func `2D resizing compresses a range along Y`() async throws {
        // Rectangle 10x30, resize y range 10...20 (length 10) to length 5
        let bounds = try await Rectangle(x: 10, y: 30)
            .resizing(.y, in: 10...20, to: 5)
            .bounds

        // Original height 30, range compressed by 5, new height 25
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 25)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 25)
    }

    @Test func `2D resizing preserves area proportionally`() async throws {
        // Circle diameter 20, resize y range 5...15 to 15 (1.5x stretch)
        let original = Circle(diameter: 20)
        let resized = original.resizing(.y, in: 5...15, to: 15)

        let originalArea = try await original.measurements.area
        let resizedArea = try await resized.measurements.area

        // The middle section (y: 5...15) gets stretched by 1.5x
        // This increases the area of that section by 1.5x
        // The area increase should be roughly 0.5 * (area of middle band)
        #expect(resizedArea > originalArea)
    }

    @Test func `2D resizing to zero removes the range`() async throws {
        // Rectangle 30x10, resize x range 10...20 to 0
        let bounds = try await Rectangle(x: 30, y: 10)
            .resizing(.x, in: 10...20, to: 0)
            .bounds

        // Original width 30, range removed (10 units), new width 20
        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 20)
    }

    @Test func `2D resizing with max alignment keeps upper geometry fixed`() async throws {
        // Rectangle 30x10, resize x range 10...20 to 15 with .max alignment
        let bounds = try await Rectangle(x: 30, y: 10)
            .resizing(.x, in: 10...20, to: 15, alignment: .max)
            .bounds

        // Right part (20-30) stays at x=30
        // Range expands leftward by 5
        #expect(bounds?.maximum.x ≈ 30)
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.size.x ≈ 35)
    }

    @Test func `2D resizing with mid alignment centers the change`() async throws {
        // Rectangle 30x10, resize x range 10...20 to 20 with .mid alignment
        let bounds = try await Rectangle(x: 30, y: 10)
            .resizing(.x, in: 10...20, to: 20, alignment: .mid)
            .bounds

        // Range center at x=15 stays fixed
        // Left part moves left by 5, right part moves right by 5
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 35)
        #expect(bounds?.size.x ≈ 40)
    }
}
