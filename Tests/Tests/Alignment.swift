import Foundation
import Testing
@testable import Cadova

struct AlignmentTests {
    // MARK: - 2D Single Axis Alignment

    @Test func `2D align minX moves left edge to origin`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .minX)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 10)
        // Y unchanged
        #expect(bounds?.minimum.y ≈ 10)
    }

    @Test func `2D align maxX moves right edge to origin`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .maxX)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -10)
        #expect(bounds?.maximum.x ≈ 0)
    }

    @Test func `2D align centerX centers horizontally`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .centerX)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
    }

    @Test func `2D align minY moves bottom edge to origin`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .minY)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 5)
        // X unchanged
        #expect(bounds?.minimum.x ≈ 20)
    }

    @Test func `2D align maxY moves top edge to origin`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .maxY)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ -5)
        #expect(bounds?.maximum.y ≈ 0)
    }

    @Test func `2D align centerY centers vertically`() async throws {
        let geometry = Rectangle(x: 10, y: 5)
            .translated(x: 20, y: 10)
            .aligned(at: .centerY)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.y ≈ -2.5)
        #expect(bounds?.maximum.y ≈ 2.5)
    }

    // MARK: - 2D Combined Alignment

    @Test func `2D align center centers on both axes`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .center)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ -3)
        #expect(bounds?.maximum.y ≈ 3)
    }

    @Test func `2D align min aligns to origin on both axes`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .min)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.x ≈ 10)
        #expect(bounds?.maximum.y ≈ 6)
    }

    @Test func `2D align max aligns max corner to origin`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .max)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -10)
        #expect(bounds?.minimum.y ≈ -6)
        #expect(bounds?.maximum.x ≈ 0)
        #expect(bounds?.maximum.y ≈ 0)
    }

    @Test func `2D align with multiple parameters`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .centerX, .bottom)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 6)
    }

    @Test func `2D align left and top aliases`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .left, .top)
        let bounds = try await geometry.bounds

        // left = minX, top = maxY
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.y ≈ 0)
    }

    @Test func `2D align right and bottom aliases`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
            .aligned(at: .right, .bottom)
        let bounds = try await geometry.bounds

        // right = maxX, bottom = minY
        #expect(bounds?.maximum.x ≈ 0)
        #expect(bounds?.minimum.y ≈ 0)
    }

    // MARK: - 3D Single Axis Alignment

    @Test func `3D align minX moves left edge to origin`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .minX)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 10)
        // Y and Z unchanged
        #expect(bounds?.minimum.y ≈ 10)
        #expect(bounds?.minimum.z ≈ 5)
    }

    @Test func `3D align centerX centers along X`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .centerX)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
    }

    @Test func `3D align minZ moves bottom to origin`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .minZ)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 3)
    }

    @Test func `3D align maxZ moves top to origin`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .maxZ)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.z ≈ -3)
        #expect(bounds?.maximum.z ≈ 0)
    }

    @Test func `3D align centerZ centers along Z`() async throws {
        let geometry = Box(x: 10, y: 5, z: 3)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .centerZ)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.z ≈ -1.5)
        #expect(bounds?.maximum.z ≈ 1.5)
    }

    // MARK: - 3D Combined Alignment

    @Test func `3D align center centers on all axes`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .center)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ -3)
        #expect(bounds?.maximum.y ≈ 3)
        #expect(bounds?.minimum.z ≈ -2)
        #expect(bounds?.maximum.z ≈ 2)
    }

    @Test func `3D align min aligns to origin on all axes`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .min)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.minimum.z ≈ 0)
    }

    @Test func `3D align centerXY centers in XY plane`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .centerXY)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ -3)
        #expect(bounds?.maximum.y ≈ 3)
        // Z unchanged
        #expect(bounds?.minimum.z ≈ 5)
    }

    @Test func `3D align with multiple parameters`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .centerX, .front, .bottom)
        let bounds = try await geometry.bounds

        // centerX, front=minY, bottom=minZ
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.minimum.z ≈ 0)
    }

    @Test func `3D align top and back aliases`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
            .aligned(at: .top, .back)
        let bounds = try await geometry.bounds

        // top = maxZ, back = maxY
        #expect(bounds?.maximum.z ≈ 0)
        #expect(bounds?.maximum.y ≈ 0)
    }

    // MARK: - whileAligned

    @Test func `2D whileAligned matches rotated around center`() async throws {
        let geometry = Rectangle(x: 10, y: 6)
            .translated(x: 20, y: 10)
        let viaWhileAligned = geometry
            .whileAligned(at: .center) { $0.rotated(90°) }
        let viaPivot = geometry.rotated(90°, around: .center)

        let whileBounds = try await viaWhileAligned.bounds
        let pivotBounds = try await viaPivot.bounds

        #expect(whileBounds?.minimum.x ≈ pivotBounds?.minimum.x)
        #expect(whileBounds?.maximum.x ≈ pivotBounds?.maximum.x)
        #expect(whileBounds?.minimum.y ≈ pivotBounds?.minimum.y)
        #expect(whileBounds?.maximum.y ≈ pivotBounds?.maximum.y)
    }

    @Test func `3D whileAligned matches rotated around center`() async throws {
        let geometry = Box(x: 10, y: 6, z: 4)
            .translated(x: 20, y: 10, z: 5)
        let viaWhileAligned = geometry
            .whileAligned(at: .center) { $0.rotated(y: 90°) }
        let viaPivot = geometry.rotated(y: 90°, around: .center)

        let whileBounds = try await viaWhileAligned.bounds
        let pivotBounds = try await viaPivot.bounds

        #expect(whileBounds?.minimum.x ≈ pivotBounds?.minimum.x)
        #expect(whileBounds?.maximum.x ≈ pivotBounds?.maximum.x)
        #expect(whileBounds?.minimum.y ≈ pivotBounds?.minimum.y)
        #expect(whileBounds?.maximum.y ≈ pivotBounds?.maximum.y)
        #expect(whileBounds?.minimum.z ≈ pivotBounds?.minimum.z)
        #expect(whileBounds?.maximum.z ≈ pivotBounds?.maximum.z)
    }

    // MARK: - Edge Cases

    @Test func `align none leaves geometry unchanged`() async throws {
        let original = Box(x: 10, y: 6, z: 4).translated(x: 20, y: 10, z: 5)
        let aligned = original.aligned(at: .none)

        let originalBounds = try await original.bounds
        let alignedBounds = try await aligned.bounds

        #expect(originalBounds?.minimum.x ≈ alignedBounds?.minimum.x)
        #expect(originalBounds?.minimum.y ≈ alignedBounds?.minimum.y)
        #expect(originalBounds?.minimum.z ≈ alignedBounds?.minimum.z)
    }

    @Test func `align already aligned geometry`() async throws {
        // Box at origin, aligned at min should stay at origin
        let geometry = Box(10).aligned(at: .min)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.minimum.z ≈ 0)
    }

    @Test func `align geometry centered at origin`() async throws {
        // Box already centered, align center should stay centered
        let geometry = Box(10).aligned(at: .center).aligned(at: .center)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
    }

    @Test func `2D align circle`() async throws {
        let geometry = Circle(diameter: 10)
            .translated(x: 20, y: 15)
            .aligned(at: .center)
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ -5)
        #expect(bounds?.maximum.y ≈ 5)
    }

    @Test func `3D align cylinder`() async throws {
        let geometry = Cylinder(diameter: 10, height: 20)
            .translated(x: 30, y: 25, z: 10)
            .aligned(at: .centerXY, .bottom)
        let bounds = try await geometry.bounds

        #expect(bounds!.minimum.x.equals(-5, within: 0.1))
        #expect(bounds!.maximum.x.equals(5, within: 0.1))
        #expect(bounds!.minimum.y.equals(-5, within: 0.1))
        #expect(bounds!.maximum.y.equals(5, within: 0.1))
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 20)
    }
}
