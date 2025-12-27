import Foundation
import Testing
@testable import Cadova

struct ProjectionTests {
    // MARK: - Basic Projection onto XY Plane

    @Test func `sphere projected creates circle`() async throws {
        let projection = Sphere(diameter: 10)
            .aligned(at: .center)
            .projected()
        let expectedCircle = Circle(diameter: 10).aligned(at: .center)

        // XOR should be empty if shapes match
        let differenceArea = try await projection.symmetricDifferenceArea(with: expectedCircle)
        #expect(differenceArea < 1)
    }

    @Test func `box projected creates rectangle`() async throws {
        let projection = Box(x: 10, y: 20, z: 5).projected()
        let expectedRectangle = Rectangle(x: 10, y: 20)

        // XOR should be empty if shapes match
        let differenceArea = try await projection.symmetricDifferenceArea(with: expectedRectangle)
        #expect(differenceArea < 0.01)
    }

    @Test func `cylinder projected creates circle`() async throws {
        let projection = Cylinder(diameter: 15, height: 30)
            .aligned(at: .centerXY)
            .projected()
        let expectedCircle = Circle(diameter: 15).aligned(at: .center)

        // XOR should be empty if shapes match
        let differenceArea = try await projection.symmetricDifferenceArea(with: expectedCircle)
        #expect(differenceArea < 1)
    }

    @Test func `translated geometry projection includes offset`() async throws {
        let geometry = Box(10)
            .translated(x: 20, y: 15)
            .projected()
        let bounds = try await geometry.bounds

        #expect(bounds?.minimum.x ≈ 20)
        #expect(bounds?.minimum.y ≈ 15)
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
    }

    // MARK: - Slice at Z

    @Test func `box sliced at Z creates rectangle`() async throws {
        let geometry = Box(x: 10, y: 20, z: 30)
            .sliced(atZ: 15)
        let bounds = try await geometry.bounds

        // Slice through box gives rectangle of X and Y dimensions
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 20)
    }

    @Test func `cylinder sliced at Z creates circle`() async throws {
        let slice = Cylinder(diameter: 20, height: 50)
            .aligned(at: .centerXY)
            .sliced(atZ: 25)
        let expectedCircle = Circle(diameter: 20).aligned(at: .center)

        // XOR should be empty if shapes match
        let differenceArea = try await slice.symmetricDifferenceArea(with: expectedCircle)
        #expect(differenceArea < 1)
    }

    @Test func `cone sliced at different Z heights creates different circles`() async throws {
        let cone = Cylinder(bottomDiameter: 20, topDiameter: 0, height: 20)
            .aligned(at: .centerXY)

        let sliceBottom = cone.sliced(atZ: 0)
        let sliceMiddle = cone.sliced(atZ: 10)
        let sliceTop = cone.sliced(atZ: 19)

        let boundsBottom = try await sliceBottom.bounds
        let boundsMiddle = try await sliceMiddle.bounds
        let boundsTop = try await sliceTop.bounds

        // Bottom is full diameter
        #expect(boundsBottom!.size.x.equals(20, within: 0.2))
        // Middle is half diameter
        #expect(boundsMiddle!.size.x.equals(10, within: 0.2))
        // Near top is very small
        #expect(boundsTop!.size.x < 2)
    }

    @Test func `slice outside geometry returns empty`() async throws {
        let geometry = Box(10).sliced(atZ: 100)
        let bounds = try await geometry.bounds

        #expect(bounds == nil)
    }

    @Test func `sphere sliced at center creates max diameter circle`() async throws {
        let slice = Sphere(diameter: 20)
            .aligned(at: .center)
            .sliced(atZ: 0)
        let expectedCircle = Circle(diameter: 20).aligned(at: .center)

        // XOR should be empty if shapes match
        let differenceArea = try await slice.symmetricDifferenceArea(with: expectedCircle)
        #expect(differenceArea < 1)
    }

    @Test func `sphere sliced off-center creates smaller circle`() async throws {
        let geometry = Sphere(diameter: 20)
            .aligned(at: .center)
            .sliced(atZ: 8)
        let bounds = try await geometry.bounds

        // Slice near edge is smaller than diameter
        #expect(bounds!.size.x < 15)
        #expect(bounds!.size.y < 15)
    }

    // MARK: - Slice Along Plane

    @Test func `slice along XY plane same as slice at Z`() async throws {
        let box = Box(x: 10, y: 20, z: 30)

        let sliceZ = box.sliced(atZ: 15)
        let slicePlane = box.sliced(along: Plane.z(15))

        let boundsZ = try await sliceZ.bounds
        let boundsPlane = try await slicePlane.bounds

        #expect(boundsZ?.size.x ≈ boundsPlane?.size.x)
        #expect(boundsZ?.size.y ≈ boundsPlane?.size.y)
    }

    @Test func `slice along tilted plane creates ellipse from cylinder`() async throws {
        let geometry = Cylinder(diameter: 10, height: 30)
            .aligned(at: .centerXY, .centerZ)
            .sliced(along: Plane.xy.rotated(y: 30°))
        let bounds = try await geometry.bounds

        // Tilted slice through cylinder creates ellipse (longer in one direction)
        #expect(bounds != nil)
        // X dimension should be stretched due to tilt
        #expect(bounds!.size.x > 10)
    }

    // MARK: - Project onto Plane

    @Test func `project onto YZ plane gives side view`() async throws {
        let geometry = Box(x: 10, y: 20, z: 30)
            .projected(onto: .yz)
        let bounds = try await geometry.bounds

        // YZ projection: X becomes viewing direction
        // Actual mapping: Z->X, Y->Y in 2D (due to rotation)
        #expect(bounds?.size.x ≈ 30) // Z dimension
        #expect(bounds?.size.y ≈ 20) // Y dimension
    }

    @Test func `project onto XZ plane gives front view`() async throws {
        let geometry = Box(x: 10, y: 20, z: 30)
            .projected(onto: .xz)
        let bounds = try await geometry.bounds

        // XZ projection: Y becomes viewing direction
        #expect(bounds?.size.x ≈ 10) // X dimension
        #expect(bounds?.size.y ≈ 30) // Z dimension
    }

    @Test func `project onto tilted plane`() async throws {
        let geometry = Box(10)
            .aligned(at: .center)
            .projected(onto: Plane.xy.rotated(y: 45°))
        let bounds = try await geometry.bounds

        // Tilted projection should show box at an angle
        #expect(bounds != nil)
        // At 45°, the diagonal of X-Z appears, which is √2 * 10
        #expect(bounds!.size.x > 10)
    }

    // MARK: - Projection with Reader Closure

    @Test func `projected with reader provides both geometries`() async throws {
        let box = Box(10)

        let result: any Geometry3D = box.projected { original, projection in
            // Use projection to create an extruded version
            projection.extruded(height: 5)
        }
        let bounds = try await result.bounds

        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 5)
    }

    @Test func `sliced with reader provides both geometries`() async throws {
        let cylinder = Cylinder(diameter: 10, height: 20)

        let result: any Geometry3D = cylinder.sliced(atZ: 10) { original, slice in
            // Use slice as a cap
            slice.extruded(height: 2)
        }
        let bounds = try await result.bounds

        #expect(bounds != nil)
        #expect(bounds?.size.z ≈ 2)
    }

    // MARK: - Complex Shapes

    @Test func `union of shapes projects correctly`() async throws {
        let geometry = Box(10)
            .adding { Box(10).translated(x: 15) }
            .projected()
        let bounds = try await geometry.bounds

        // Two boxes side by side project to combined width
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 25) // 0-10 and 15-25
    }

    @Test func `hollow cylinder projection is ring`() async throws {
        let projection = Cylinder(diameter: 20, height: 10)
            .aligned(at: .centerXY)
            .subtracting { Cylinder(diameter: 10, height: 10).aligned(at: .centerXY) }
            .projected()
        let expectedRing = Circle(diameter: 20).aligned(at: .center)
            .subtracting { Circle(diameter: 10).aligned(at: .center) }

        // XOR should be empty if shapes match
        let differenceArea = try await projection.symmetricDifferenceArea(with: expectedRing)
        #expect(differenceArea < 1)
    }

    @Test func `hollow cylinder slice is ring`() async throws {
        let slice = Cylinder(diameter: 20, height: 10)
            .aligned(at: .centerXY)
            .subtracting { Cylinder(diameter: 10, height: 10).aligned(at: .centerXY) }
            .sliced(atZ: 5)
        let expectedRing = Circle(diameter: 20).aligned(at: .center)
            .subtracting { Circle(diameter: 10).aligned(at: .center) }

        // XOR should be empty if shapes match
        let differenceArea = try await slice.symmetricDifferenceArea(with: expectedRing)
        #expect(differenceArea < 1)
    }
}
