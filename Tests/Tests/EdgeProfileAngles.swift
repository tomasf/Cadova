import Foundation
import Testing
@testable import Cadova

struct EdgeProfileAngleTests {
    @Test func chamferNegativeShapeAt90Degrees() async throws {
        // A chamfer at 90° should produce a rectangular negative shape
        let profile = EdgeProfile.chamfer(depth: 5)
        let negativeShape = profile.negativeShape(for: 90°)

        let result = try await negativeShape.measurements
        let bounds = result.boundingBox!

        // The chamfer triangle is 5x5, so negative shape should be 5x5 too
        #expect(bounds.size.x ≈ 5.0)
        #expect(bounds.size.y ≈ 5.0)
    }

    @Test func chamferNegativeShapeAt60Degrees() async throws {
        // A chamfer at 60° should produce a wedge-based negative shape
        let profile = EdgeProfile.chamfer(depth: 5)
        let negativeShape = profile.negativeShape(for: 60°)

        let result = try await negativeShape.measurements

        // Should still have valid bounds (profile was adapted)
        #expect(result.boundingBox != nil)
    }

    @Test func chamferNegativeShapeAt120Degrees() async throws {
        // A chamfer at 120° should produce a wedge-based negative shape
        let profile = EdgeProfile.chamfer(depth: 5)
        let negativeShape = profile.negativeShape(for: 120°)

        let result = try await negativeShape.measurements

        // Should still have valid bounds (profile was adapted)
        #expect(result.boundingBox != nil)
    }

    @Test func filletNegativeShapeAt90Degrees() async throws {
        // A fillet at 90° should produce a quarter-circle arc
        let profile = EdgeProfile.fillet(radius: 5)
        let negativeShape = profile.negativeShape(for: 90°)

        let result = try await negativeShape.measurements
        let bounds = result.boundingBox!

        // The fillet should fit in a 5x5 area
        #expect(bounds.size.x ≈ 5.0)
        #expect(bounds.size.y ≈ 5.0)
    }

    @Test func filletNegativeShapeAt60Degrees() async throws {
        // A fillet at 60° should produce a 60° arc
        let profile = EdgeProfile.fillet(radius: 5)
        let negativeShape = profile.negativeShape(for: 60°)

        let result = try await negativeShape.measurements

        // Should have valid bounds
        #expect(result.boundingBox != nil)

        // The arc should be different from the 90° case
        // At 60°, the arc spans less angle, so different dimensions
    }

    @Test func filletNegativeShapeAt120Degrees() async throws {
        // A fillet at 120° should produce a 120° arc
        let profile = EdgeProfile.fillet(radius: 5)
        let negativeShape = profile.negativeShape(for: 120°)

        let result = try await negativeShape.measurements

        // Should have valid bounds
        #expect(result.boundingBox != nil)
    }

    @Test func profileReferenceAngleIsStored() {
        let profile90 = EdgeProfile.chamfer(depth: 5)
        let profile60 = EdgeProfile(referenceAngle: 60°) {
            Polygon([[0, 0], [5, 0], [0, 5]])
        }

        #expect(profile90.referenceAngle == 90°)
        #expect(profile60.referenceAngle == 60°)
    }

    @Test func chamferOnBoxEdge() async throws {
        // Test that chamfer can be applied at 90° (box edge)
        let result = try await Box(20)
            .cuttingEdgeProfile(.chamfer(depth: 2), on: .top)
            .measurements

        // Should produce a valid geometry
        #expect(result.boundingBox != nil)
        // Box should still be roughly 20x20x20 (minus the chamfer)
        #expect(result.boundingBox!.size.z ≈ 20.0)
    }

    @Test func filletOnBoxEdge() async throws {
        // Test that fillet can be applied at 90° (box edge)
        let result = try await Box(20)
            .cuttingEdgeProfile(.fillet(radius: 2), on: .top)
            .measurements

        // Should produce a valid geometry
        #expect(result.boundingBox != nil)
        // Box should still be roughly 20x20x20 (minus the fillet)
        #expect(result.boundingBox!.size.z ≈ 20.0)
    }
}
