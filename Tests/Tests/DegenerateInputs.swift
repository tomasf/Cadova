import Foundation
import Testing
@testable import Cadova

/// Degenerate arguments and degenerate *inputs* are two different things, and both used to end in a
/// division by zero somewhere far from where the mistake was made.
///
/// * A shape or operation given a zero or negative measurement has to resolve to empty geometry, and
///   say so — never divide by it. `DegenerateSizeTests` states the convention for the primitives:
///   parametric design produces non-positive intermediate values easily, so these resolve to empty
///   rather than crashing. Operations follow the same rule. Dividing instead let a NaN into the node
///   tree, where it tripped a `Vector` precondition that names neither the operation nor the value.
/// * An operation driven by the *measured* extent of the geometry it is given has to cope with that
///   extent being zero. Geometry with no extent along an axis is not empty — a warp or a zero scale
///   produces exactly that — so the guard has to be on the measurement, not on emptiness.
struct DegenerateInputTests {
    /// Non-empty geometry with no extent at all along X.
    private static var flatInX: any Geometry3D {
        Box(x: 10, y: 20, z: 30).scaled(x: 0)
    }

    // MARK: - Cylinder cross sections

    @Test func `a cylinder with no height has no cross section`() throws {
        // A cylinder of zero or negative height is empty geometry, so there is no cross-section to
        // take. Interpolating one divides by the height.
        #expect(Cylinder(radius: 5, height: 0).crossSection(at: 0) == nil)
        #expect(Cylinder(radius: 5, height: -3).crossSection(at: 0) == nil)
        #expect(Cylinder(bottomRadius: 2, topRadius: 6, height: 0).crossSection(at: 1) == nil)
        #expect(Cylinder(bottomRadius: 2, topRadius: 6, height: -3).crossSection(at: 1) == nil)
    }

    @Test func `a cone's cross section interpolates between its end radii`() throws {
        let cone = Cylinder(bottomRadius: 2, topRadius: 6, height: 10)

        #expect(try #require(cone.crossSection(at: 0)).radius ≈ 2)
        #expect(try #require(cone.crossSection(at: 5)).radius ≈ 4)
        #expect(try #require(cone.crossSection(at: 10)).radius ≈ 6)
    }

    // MARK: - Ellipses and ellipsoids

    @Test func `an ellipse with no size is empty`() async throws {
        #expect(try await Circle.ellipse(size: .zero).node.isEmpty)
        #expect(try await Circle.ellipse(size: .zero).measurements.isEmpty)
        #expect(try await Circle.ellipse(x: -4, y: -2).node.isEmpty)
        #expect(try await Circle.ellipse(x: 0, y: 0).measurements.isEmpty)
    }

    @Test func `an ellipse with one negative dimension is empty, not mirrored`() async throws {
        // Guarding only the largest dimension let this through: the circle was built at diameter 20
        // and then scaled by (1, -0.5), giving a full-size ellipse flipped in Y. A wrong answer at
        // full size is worse than an empty one, because nothing about it looks wrong.
        #expect(try await Circle.ellipse(x: 20, y: -10).node.isEmpty)
        #expect(try await Circle.ellipse(x: 20, y: -10).measurements.isEmpty)
        #expect(try await Circle.ellipse(x: -20, y: 10).node.isEmpty)
        #expect(try await Circle.ellipse(x: 20, y: 0).node.isEmpty)
    }

    @Test func `an ellipse fills the size it is given`() async throws {
        let bounds = try #require(try await Circle.ellipse(x: 20, y: 10).bounds)

        #expect(bounds.size.x ≈ 20)
        #expect(bounds.size.y ≈ 10)
    }

    @Test func `an ellipsoid with no size is empty`() async throws {
        #expect(try await Sphere.ellipsoid(size: .zero).node.isEmpty)
        #expect(try await Sphere.ellipsoid(size: .zero).measurements.isEmpty)
        #expect(try await Sphere.ellipsoid(x: -4, y: -2, z: -1).node.isEmpty)
        #expect(try await Sphere.ellipsoid(x: 0, y: 0, z: 0).measurements.isEmpty)
    }

    @Test func `an ellipsoid with one negative dimension is empty, not inside out`() async throws {
        // As with the ellipse, a negative dimension came through the scale as a mirror. In 3D that
        // turns the ellipsoid inside out, which is a full-size wrong answer.
        #expect(try await Sphere.ellipsoid(x: 20, y: -10, z: 10).node.isEmpty)
        #expect(try await Sphere.ellipsoid(x: 20, y: -10, z: 10).measurements.isEmpty)
        #expect(try await Sphere.ellipsoid(x: 20, y: 10, z: 0).node.isEmpty)
    }

    @Test func `an ellipsoid fills the size it is given`() async throws {
        let bounds = try #require(try await Sphere.ellipsoid(x: 20, y: 10, z: 4).bounds)

        #expect(bounds.size.x ≈ 20)
        #expect(bounds.size.y ≈ 10)
        #expect(bounds.size.z ≈ 4)
    }

    // MARK: - Helical sweeps

    @Test func `a helix with a zero pitch is empty`() async throws {
        // The number of turns is the height divided by the pitch, so a zero pitch used to reach
        // `Int(ceil(.infinity))` and trap on a message about converting a Double.
        let helix = Circle(diameter: 2).translated(x: 10).sweptAlongHelix(pitch: 0, height: 20)

        #expect(try await helix.node.isEmpty)
        #expect(try await helix.measurements.isEmpty)
    }

    @Test func `a helix with a negative pitch is empty`() async throws {
        // A negative pitch used to be accepted and quietly produce a fragment of a single turn
        // instead of the left-handed helix it looks like it asks for.
        let helix = Circle(diameter: 2).translated(x: 10).sweptAlongHelix(pitch: -5, height: 20)

        #expect(try await helix.node.isEmpty)
        #expect(try await helix.measurements.isEmpty)
    }

    @Test func `a helix whose profile touches the axis is empty`() async throws {
        // The profile's distance from the Z axis becomes the helix radius, and it also divides the
        // extrusion length. A profile reaching only x = 0 made that division 0/0, putting NaN into
        // every vertex and tripping `Vector`'s precondition rather than saying what was wrong.
        let onAxis = Circle(diameter: 2).translated(x: -1).sweptAlongHelix(pitch: 4, height: 20)
        #expect(try await onAxis.node.isEmpty)
        #expect(try await onAxis.measurements.isEmpty)

        let leftOfAxis = Circle(diameter: 2).translated(x: -10).sweptAlongHelix(pitch: 4, height: 20)
        #expect(try await leftOfAxis.node.isEmpty)
    }

    @Test func `a helix with a non-positive height is empty`() async throws {
        // A negative height already produced nothing, by way of an intersection with a Box of
        // negative height. It now says so instead of resolving to empty without comment.
        let negative = Circle(diameter: 2).translated(x: 10).sweptAlongHelix(pitch: 4, height: -20)
        #expect(try await negative.node.isEmpty)

        let zero = Circle(diameter: 2).translated(x: 10).sweptAlongHelix(pitch: 4, height: 0)
        #expect(try await zero.node.isEmpty)
    }

    @Test func `a helix with a negative pitch says how to build a left-handed one`() async throws {
        // The warning is checked in a child process because the logger writes to standard output.
        // The documented way to get a left-handed helix is to flip the result, and the message has
        // to keep saying so for the code and the documentation to agree.
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            _ = Circle(diameter: 2).translated(x: 10).sweptAlongHelix(pitch: -5, height: 20)
        }
        let output = String(decoding: try #require(result?.standardOutputContent), as: UTF8.self)

        #expect(output.contains("Flip the resulting geometry"))
    }

    @Test func `a helix with a positive pitch covers the requested height`() async throws {
        let bounds = try #require(try await Circle(diameter: 2).translated(x: 10)
            .sweptAlongHelix(pitch: 5, height: 20)
            .bounds)

        #expect(bounds.minimum.z ≈ 0)
        #expect(bounds.maximum.z ≈ 20)
    }

    // MARK: - Resizing

    @Test func `resizing to a zero length is empty`() async throws {
        // Scaling by exactly zero used to collapse the geometry into a zero-volume mesh that both
        // `node.isEmpty` and `measurements.isEmpty` reported as solid. Empty is the honest answer,
        // and both have to agree on it.
        let resized = Box(x: 10, y: 20, z: 30).resized(x: 0, y: 10, z: 10)

        #expect(try await resized.node.isEmpty)
        #expect(try await resized.measurements.isEmpty)
        #expect(try await Rectangle(x: 10, y: 20).resized(x: 0, y: 5).node.isEmpty)
        #expect(try await Rectangle(x: 10, y: 20).resized(x: 0, y: 5).measurements.isEmpty)
    }

    @Test func `resizing by a calculator that returns nothing is empty`() async throws {
        // The other overloads check the lengths they are handed, but a calculator produces them
        // after that check, so this door was still open onto the zero-volume mesh.
        let flattened = Box(10).resized(alignment: .center) { _ in Vector3D(10, 10, 0) }
        #expect(try await flattened.measurements.isEmpty)

        let inverted = Box(10).resized(alignment: .center) { size in Vector3D(size.x, size.y, -5) }
        #expect(try await inverted.measurements.isEmpty)

        let unchanged = Box(10).resized(alignment: .center) { $0 }
        #expect(try await unchanged.measurements.isEmpty == false)
    }

    @Test func `resizing to a negative length is empty`() async throws {
        #expect(try await Rectangle(x: 10, y: 20).resized(x: 5, y: -1).node.isEmpty)
        #expect(try await Rectangle(x: 10, y: 20).resized(x: -1, y: .proportional).measurements.isEmpty)
        #expect(try await Box(x: 10, y: 20, z: 30).resized(y: -4, z: .proportional).node.isEmpty)
        #expect(try await Box(x: 10, y: 20, z: 30).resized(x: 5, y: 5, z: -5).measurements.isEmpty)
    }

    @Test func `resizing to an impossible length says which axis it was`() async throws {
        // Checked in a child process because the logger writes to standard output.
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            _ = Box(x: 10, y: 20, z: 30).resized(x: 0, y: 10, z: 10)
        }
        let output = String(decoding: try #require(result?.standardOutputContent), as: UTF8.self)

        #expect(output.contains("Resize target x must be greater than zero"))
    }

    @Test func `resizing geometry with no extent leaves that axis alone`() async throws {
        // There is no factor that scales a zero extent to 5, so X keeps the only value it can have
        // instead of becoming infinite. The axes that do have an extent are resized normally.
        let bounds = try #require(try await Self.flatInX.resized(x: 5, y: 5, z: 5).bounds)

        #expect(bounds.size.x ≈ 0)
        #expect(bounds.size.y ≈ 5)
        #expect(bounds.size.z ≈ 5)
    }

    @Test func `resizing proportionally to an axis with no extent leaves the other axes alone`() async throws {
        let bounds = try #require(try await Self.flatInX
            .resized(x: 4, y: .proportional, z: .proportional)
            .bounds)

        #expect(bounds.size.x ≈ 0)
        #expect(bounds.size.y ≈ 20)
        #expect(bounds.size.z ≈ 30)
    }

    // MARK: - Deformations driven by a measured extent

    @Test func `deforming geometry with no footprint leaves it unchanged`() async throws {
        let patch = BezierPatch(controlPoints: [
            [[0, 0, 0], [10, 0, 0], [20, 0, 0]],
            [[0, 10, 0], [10, 10, 5], [20, 10, 0]],
            [[0, 20, 0], [10, 20, 0], [20, 20, 0]]
        ])
        let original = try #require(try await Self.flatInX.bounds)
        let deformed = try #require(try await Self.flatInX.deformed(by: patch).bounds)

        #expect(deformed ≈ original)
    }

    @Test func `making 2D geometry with no extent follow a path leaves it unchanged`() async throws {
        let path = BezierPath2D(linesBetween: [[0, 0], [20, 0]])
        let flat = Rectangle(x: 10, y: 10).scaled(x: 0)
        let original = try #require(try await flat.bounds)
        let followed = try #require(try await flat.following(path: path).bounds)

        #expect(followed ≈ original)
    }

    @Test func `making 3D geometry with no extent follow a path leaves it unchanged`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 20]])
        let flat = Box(x: 10, y: 10, z: 10).scaled(z: 0)
        let original = try #require(try await flat.bounds)
        let followed = try #require(try await flat
            .following(path: path, pointing: .positiveX, toward: .direction(.positiveX))
            .bounds)

        #expect(followed ≈ original)
    }
}
