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
}
