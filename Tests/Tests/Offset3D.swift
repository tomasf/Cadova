import Foundation
import Testing
@testable import Cadova

struct Offset3DTests {
    // Coarser than the default, to keep the tests quick: rounded parts are then accurate to 0.04
    let segmentation = Segmentation.adaptive(minAngle: 2°, minSize: 0.4)

    @Test func `offsetting a box inward shrinks it by the amount on every side, with sharp corners`() async throws {
        let offset = Box(20).offset(amount: -2).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        let volume = try await offset.measurements.volume

        let expectedVolume = 16.0 * 16 * 16
        #expect(bounds ≈ BoundingBox3D(minimum: [2, 2, 2], maximum: [18, 18, 18]))
        #expect(volume.equals(expectedVolume, within: 0.01))
    }

    @Test func `offsetting a box outward rounds its edges and corners with the amount as radius`() async throws {
        let offset = Box(20).offset(amount: 2).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        let volume = try await offset.measurements.volume

        // The box, a slab on each face, a quarter cylinder along each edge and an eighth of a sphere at each corner
        let faces = 6 * 20.0 * 20 * 2
        let edges = 12 * 20 * Double.pi * 2 * 2 / 4
        let corners = 4.0 / 3 * .pi * 2 * 2 * 2
        let expectedVolume = 8000 + faces + edges + corners
        // Rounded parts are accurate to a tenth of the segmentation's minimum size
        #expect(bounds.minimum.x.equals(-2, within: 0.04) && bounds.maximum.z.equals(22, within: 0.04))
        #expect(volume.equals(expectedVolume, within: expectedVolume * 0.002))
    }

    @Test func `offsetting inward rounds concave corners with the amount as radius`() async throws {
        // An L-shaped plate: the concave inner corner is where the rounding appears
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let volume = try await plate.offset(amount: -2).withSegmentation(segmentation).measurements.volume

        // Offsetting by 2 shrinks the L to 26 × 26 minus a 15 × 15 notch, and its height from 10 to 6. A sharp
        // concave corner would give exactly that; rounding keeps the 2 × 2 corner square minus a quarter disc
        let sharpArea = 26.0 * 26 - 15 * 15
        let expectedVolume = (sharpArea + 4 - Double.pi) * 6
        #expect(volume.equals(expectedVolume, within: expectedVolume * 0.001))
    }

    @Test func `offsetting a sphere changes its radius`() async throws {
        let offset = Sphere(radius: 10).offset(amount: 3).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        #expect(bounds.size.x.equals(26, within: 0.1))
        #expect(bounds.size.z.equals(26, within: 0.1))
    }

    @Test func `parts thinner than twice the amount disappear when offsetting inward`() async throws {
        let plate = Box([20, 20, 3]).offset(amount: -2).withSegmentation(segmentation)
        #expect(try await plate.measurements.volume == 0)

        // A thin fin on a thick base: the fin goes, and only bulges the base's offset top up a little, where the
        // corners at the fin's foot are the closest surface: √(0.5² + h²) = 2 at its center line
        let finned = Box([20, 20, 10])
            .adding { Box([1, 20, 10]).translated(x: 10, z: 10) }
            .offset(amount: -2)
            .withSegmentation(segmentation)
        let bounds = try #require(try await finned.bounds)
        #expect(bounds.maximum.z.equals(10 - (4 - 0.25).squareRoot(), within: 0.04))
    }

    @Test func `a zero offset leaves the geometry unchanged`() async throws {
        let volume = try await Box(10).offset(amount: 0).measurements.volume
        #expect(volume.equals(1000, within: 1e-9))
    }

    @Test func `hollowing leaves walls of the given thickness`() async throws {
        let volume = try await Box(20).hollowed(wallThickness: 2).withSegmentation(segmentation).measurements.volume
        let expectedVolume = 20.0 * 20 * 20 - 16 * 16 * 16
        #expect(volume.equals(expectedVolume, within: 0.01))
    }

    @Test func `offsetting with a reader provides the original and the offset`() async throws {
        // Everything within 2 of the surface: the box minus its inward offset
        let shell = Box(10).offset(amount: -2) { original, offset in
            original.subtracting { offset }
        }
        let volume = try await shell.withSegmentation(segmentation).measurements.volume
        #expect(volume.equals(1000 - 6 * 6 * 6, within: 0.01))
    }

    @Test func `hollowing with a reader provides the original and the hollowed geometry`() async throws {
        // The original minus its shell leaves the cavity
        let cavity = Box(10).hollowed(wallThickness: 2) { original, hollowed in
            original.subtracting { hollowed }
        }
        let volume = try await cavity.withSegmentation(segmentation).measurements.volume
        #expect(volume.equals(6 * 6 * 6, within: 0.01))
    }

    @Test func `hollowing keeps parts thinner than two walls solid`() async throws {
        let volume = try await Box([20, 20, 3]).hollowed(wallThickness: 2).measurements.volume
        #expect(volume.equals(1200, within: 1e-6))
    }
}
