import Foundation
import Testing
@testable import Cadova

struct Geometry3DTests {
    @Test func `3D boolean operations produce correct geometry`() async throws {
        try await Box([20, 20, 20])
            .aligned(at: .center)
            .intersecting {
                Sphere(diameter: 23)
            }
            .subtracting {
                Cylinder(diameter: 2, height: 30)
                    .repeated(around: .x, in: 0°..<360°, count: 12)
                    .distributed(at: [0°, 90°], around: .z)
            }
            .expectEquals(goldenFile: "3d/basics")
    }

    @Test func `empty boolean operations have no effect`() async throws {
        try await Box([10, 20, 30])
            .subtracting {}
            .adding {}
            .expectEquals(goldenFile: "3d/empty")
    }

    @Test func `box corners and edges can be rounded`() async throws {
        try await Stack(.x, spacing: 1) {
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
                .withSegmentation(count: 20)
            Box([3, 4, 18])
                .cuttingEdgeProfile(.fillet(radius: 2), on: .topRight, along: .x)
            Box([8, 10, 6])
                .cuttingEdgeProfile(.fillet(radius: 2.5), on: .bottom, along: .y)
        }
        .expectEquals(goldenFile: "3d/rounded-box")
    }

    @Test func `cuttingEdgeProfile(using:) places asymmetric shape consistently across all six sides`() async throws {
        // An asymmetric profile (not symmetric in either axis). If the per-side
        // chirality correction is wrong on any side, the cut on that side would
        // be mirrored relative to its neighbours, producing a visibly different
        // combined result.
        let profile: @Sendable () -> any Geometry2D = {
            Rectangle([6, 3])
                .aligned(at: .center)
                .subtracting {
                    Rectangle([2, 1.5])
                        .translated(x: 1, y: 0)
                }
        }
        let edge = EdgeProfile.chamfer(depth: 0.5)
        let sides: [DirectionalAxis<D3>] = [.top, .bottom, .left, .right, .front, .back]

        let geometry = sides.enumerated().mapUnion { index, side in
            Box(10)
                .aligned(at: .center)
                .cuttingEdgeProfile(edge, on: side, using: profile)
                .translated(x: Double(index) * 12)
        }

        try await geometry.expectEquals(goldenFile: "3d/edge-profile-side-orientation")
    }

    @Test func `cylinders support various dimension specifications`() async throws {
        try await Stack(.y, spacing: 1) {
            Cylinder(bottomRadius: 3, topRadius: 6, height: 10)
            Cylinder(largerDiameter: 10, apexAngle: 10°, height: 20)
            Cylinder(largerDiameter: 20, apexAngle: -30°, height: 25)
            Cylinder(smallerDiameter: 8, apexAngle: 60°, height: 10)
            Cylinder(bottomDiameter: 10, topDiameter: 20, apexAngle: 20°)
        }
        .expectEquals(goldenFile: "3d/cylinders")
    }

    @Test func `cylinder supports pointy bottom with expected cone volume`() async throws {
        let topDiameter = 10.0
        let height = 12.0
        let cone = Cylinder(bottomDiameter: 0, topDiameter: topDiameter, height: height)
            .withSegmentation(count: 120)

        let volume = try await cone.measurements.volume
        let radius = topDiameter / 2
        let expectedVolume = Double.pi * radius * radius * height / 3

        #expect(volume.equals(expectedVolume, within: 1))
    }

    @Test func `cylinder supports slant height initializer`() {
        let cylinder = Cylinder(bottomDiameter: 10, topDiameter: 20, slantHeight: 13)

        #expect(cylinder.bottom.diameter ≈ 10)
        #expect(cylinder.top.diameter ≈ 20)
        #expect(cylinder.height ≈ 12)
        #expect(cylinder.slantHeight ≈ 13)
    }

    @Test func `cylinder supports circle-based initializer`() {
        let cylinder = Cylinder(bottom: Circle(diameter: 10), top: Circle(diameter: 20), height: 12)

        #expect(cylinder.bottom.diameter ≈ 10)
        #expect(cylinder.top.diameter ≈ 20)
        #expect(cylinder.height ≈ 12)
    }

    @Test func `cylinder supports top diameter apex angle and slant height initializer`() {
        let expanding = Cylinder(topDiameter: 14, apexAngle: 60°, slantHeight: 10)
        let narrowing = Cylinder(topDiameter: 14, apexAngle: -60°, slantHeight: 10)
        let expectedHeight = 10 * cos(30°)

        #expect(expanding.bottom.diameter ≈ 4)
        #expect(expanding.top.diameter ≈ 14)
        #expect(expanding.height ≈ expectedHeight)

        #expect(narrowing.bottom.diameter ≈ 24)
        #expect(narrowing.top.diameter ≈ 14)
        #expect(narrowing.height ≈ expectedHeight)
    }

    @Test func `cylinder supports end-specific diameter apex angle and height initializers`() {
        let expandingFromBottom = Cylinder(bottomDiameter: 4, apexAngle: 60°, height: 10)
        let narrowingFromBottom = Cylinder(bottomDiameter: 24, apexAngle: -60°, height: 10)
        let expandingToTop = Cylinder(topDiameter: 14, apexAngle: 60°, height: 10)
        let narrowingToTop = Cylinder(topDiameter: 14, apexAngle: -60°, height: 10)
        let expectedDiameterDifference = 2 * 10 * tan(30°)

        #expect(expandingFromBottom.bottom.diameter ≈ 4)
        #expect(expandingFromBottom.top.diameter ≈ (4 + expectedDiameterDifference))

        #expect(narrowingFromBottom.bottom.diameter ≈ 24)
        #expect(narrowingFromBottom.top.diameter ≈ (24 - expectedDiameterDifference))

        #expect(expandingToTop.bottom.diameter ≈ (14 - expectedDiameterDifference))
        #expect(expandingToTop.top.diameter ≈ 14)

        #expect(narrowingToTop.bottom.diameter ≈ (14 + expectedDiameterDifference))
        #expect(narrowingToTop.top.diameter ≈ 14)
    }

    @Test func `cylinder supports bottom diameter apex angle and slant height initializer`() {
        let expanding = Cylinder(bottomDiameter: 4, apexAngle: 60°, slantHeight: 10)
        let narrowing = Cylinder(bottomDiameter: 24, apexAngle: -60°, slantHeight: 10)
        let expectedHeight = 10 * cos(30°)

        #expect(expanding.bottom.diameter ≈ 4)
        #expect(expanding.top.diameter ≈ 14)
        #expect(expanding.height ≈ expectedHeight)

        #expect(narrowing.bottom.diameter ≈ 24)
        #expect(narrowing.top.diameter ≈ 14)
        #expect(narrowing.height ≈ expectedHeight)
    }

    @Test func `projected onto plane produces correct 2D shape`() async throws {
        // A box projected onto XY should give a rectangle matching the box's XY dimensions
        let xyBounds = try await Box(x: 10, y: 20, z: 30)
            .projected(onto: .xy)
            .bounds
        #expect(xyBounds?.size.x ≈ 10)
        #expect(xyBounds?.size.y ≈ 20)

        // Same box projected onto YZ plane - the 2D result has Y→X and Z→Y
        let yzBounds = try await Box(x: 10, y: 20, z: 30)
            .projected(onto: .yz)
            .bounds
        #expect(yzBounds?.size.x ≈ 30)
        #expect(yzBounds?.size.y ≈ 20)

        // Projected onto XZ plane - the 2D result has X→X and Z→Y
        let xzBounds = try await Box(x: 10, y: 20, z: 30)
            .projected(onto: .xz)
            .bounds
        #expect(xzBounds?.size.x ≈ 10)
        #expect(xzBounds?.size.y ≈ 30)
    }
}
