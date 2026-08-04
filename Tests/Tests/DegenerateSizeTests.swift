import Foundation
import Testing
@testable import Cadova

/// Primitive shapes allow zero and negative sizes; they resolve to empty (or a sensible degenerate
/// reduction, such as a hole-less disk/cylinder) rather than crashing. This matters because parametric
/// design can easily produce zero or negative intermediate values.
///
/// Most of these cases are pruned to `.empty` structurally at construction time (`node.isEmpty`), via
/// `PrimitiveShape2D`/`PrimitiveShape3D.isEmpty` in `GeometryNode+Creation.swift` and the propagation of
/// that emptiness through booleans/transforms/extrusions. The exception is a boolean difference whose
/// operands are individually non-empty but geometrically cancel out (e.g. a `Ring`/`Tube` where the inner
/// diameter is at least as large as the outer one) — that only resolves to empty once the CSG operation is
/// actually evaluated, so `node.isEmpty` stays `false` while `measurements.isEmpty` is `true`. Both are
/// checked below so a regression in either layer's pruning is caught.
struct DegenerateSizeTests {
    @Test func `circle with zero or negative radius is empty`() async throws {
        #expect(Circle(radius: 0).area == 0)
        #expect(Circle(radius: -5).area == 0)
        #expect(Circle(diameter: -10).area == 0)
        #expect(try await Circle(radius: 0).node.isEmpty)
        #expect(try await Circle(radius: 0).measurements.isEmpty)
        #expect(try await Circle(radius: -5).node.isEmpty)
        #expect(try await Circle(radius: -5).measurements.isEmpty)
        #expect(try await Circle(diameter: 0).node.isEmpty)
        #expect(try await Circle(diameter: -10).node.isEmpty)
        #expect(try await Circle(radius: 5).node.isEmpty == false)
        #expect(try await Circle(radius: 5).measurements.isEmpty == false)
    }

    @Test func `regular polygon with zero or negative circumradius is empty`() async throws {
        #expect(RegularPolygon(sideCount: 6, circumradius: 0).area == 0)
        #expect(RegularPolygon(sideCount: 6, circumradius: -3).area == 0)
        #expect(try await RegularPolygon(sideCount: 6, circumradius: 0).node.isEmpty)
        #expect(try await RegularPolygon(sideCount: 6, circumradius: 0).measurements.isEmpty)
        #expect(try await RegularPolygon(sideCount: 6, circumradius: -3).node.isEmpty)
        #expect(try await RegularPolygon(sideCount: 6, circumradius: -3).measurements.isEmpty)
        #expect(try await RegularPolygon(sideCount: 6, circumradius: 3).node.isEmpty == false)
    }

    @Test func `ring with non-positive outer diameter is empty`() async throws {
        #expect(Ring(outerDiameter: 0, innerDiameter: 4).area == 0)
        #expect(Ring(outerDiameter: -10, innerDiameter: 4).area == 0)
        #expect(try await Ring(outerDiameter: 0, innerDiameter: 4).node.isEmpty)
        #expect(try await Ring(outerDiameter: 0, innerDiameter: 4).measurements.isEmpty)
        #expect(try await Ring(outerDiameter: -10, innerDiameter: 4).node.isEmpty)
        #expect(try await Ring(outerDiameter: -10, innerDiameter: 4).measurements.isEmpty)
    }

    @Test func `ring with non-positive inner diameter becomes a solid disk`() async throws {
        let ring = Ring(outerDiameter: 10, innerDiameter: 0)
        #expect(ring.area == Circle(diameter: 10).area)
        let diskArea = try await Circle(diameter: 10).measurements.area
        #expect(try await ring.node.isEmpty == false)
        #expect(try await ring.measurements.isEmpty == false)
        #expect(try await ring.measurements.area ≈ diskArea)

        let negativeInner = Ring(outerDiameter: 10, innerDiameter: -2)
        #expect(negativeInner.area == Circle(diameter: 10).area)
        #expect(try await negativeInner.node.isEmpty == false)
        #expect(try await negativeInner.measurements.area ≈ diskArea)
    }

    @Test func `ring with inner diameter at least as large as outer is empty`() async throws {
        #expect(Ring(outerDiameter: 2, innerDiameter: 10).area == 0)
        #expect(Ring(outerDiameter: 5, innerDiameter: 5).area == 0)
        // Both circles are individually non-empty nodes here, so this only resolves to empty once
        // the boolean difference is actually evaluated — construction-time pruning can't catch it.
        #expect(try await Ring(outerDiameter: 2, innerDiameter: 10).node.isEmpty == false)
        #expect(try await Ring(outerDiameter: 2, innerDiameter: 10).measurements.isEmpty)
        #expect(try await Ring(outerDiameter: 5, innerDiameter: 5).measurements.isEmpty)
    }

    @Test func `tube with non-positive outer diameter or height is empty`() async throws {
        #expect(try await Tube(outerDiameter: -10, innerDiameter: 4, height: 5).node.isEmpty)
        #expect(try await Tube(outerDiameter: -10, innerDiameter: 4, height: 5).measurements.isEmpty)
        #expect(try await Tube(outerDiameter: 10, innerDiameter: 4, height: 0).node.isEmpty)
        #expect(try await Tube(outerDiameter: 10, innerDiameter: 4, height: -5).node.isEmpty)
        #expect(try await Tube(outerDiameter: 10, innerDiameter: 4, height: -5).measurements.isEmpty)
    }

    @Test func `tube with non-positive inner diameter becomes a solid cylinder`() async throws {
        let tube = Tube(outerDiameter: 10, innerDiameter: -2, height: 5)
        let solidVolume = try await Cylinder(diameter: 10, height: 5).measurements.volume
        #expect(try await tube.node.isEmpty == false)
        #expect(try await tube.measurements.isEmpty == false)
        #expect(try await tube.measurements.volume ≈ solidVolume)
    }

    @Test func `tube with inner diameter at least as large as outer is empty`() async throws {
        // Same construction-time-vs-evaluation-time distinction as Ring, above.
        #expect(try await Tube(outerDiameter: 2, innerDiameter: 10, height: 5).node.isEmpty == false)
        #expect(try await Tube(outerDiameter: 2, innerDiameter: 10, height: 5).measurements.isEmpty)
    }

    @Test func `torus with non-positive minor radius is empty`() async throws {
        #expect(try await Torus(minorRadius: 0, majorRadius: 5).node.isEmpty)
        #expect(try await Torus(minorRadius: 0, majorRadius: 5).measurements.isEmpty)
        #expect(try await Torus(minorRadius: -2, majorRadius: 5).node.isEmpty)
        #expect(try await Torus(minorRadius: -2, majorRadius: 5).measurements.isEmpty)
        // Previously this combination crashed a precondition (ordering check) before ever
        // reaching the degenerate-radius handling.
        #expect(try await Torus(minorRadius: -2, majorRadius: -100).node.isEmpty)
        #expect(try await Torus(minorRadius: -2, majorRadius: -100).measurements.isEmpty)
    }

    @Test func `sphere with zero or negative radius is empty`() async throws {
        #expect(try await Sphere(radius: 0).node.isEmpty)
        #expect(try await Sphere(radius: 0).measurements.isEmpty)
        #expect(try await Sphere(radius: -5).node.isEmpty)
        #expect(try await Sphere(radius: -5).measurements.isEmpty)
        #expect(try await Sphere(diameter: -10).node.isEmpty)
    }

    @Test func `box with a zero or negative dimension is empty`() async throws {
        #expect(try await Box(x: 0, y: 10, z: 10).node.isEmpty)
        #expect(try await Box(x: 0, y: 10, z: 10).measurements.isEmpty)
        #expect(try await Box(x: -5, y: 10, z: 10).node.isEmpty)
        #expect(try await Box(x: -5, y: 10, z: 10).measurements.isEmpty)
        #expect(try await Box(-5).node.isEmpty)
        #expect(try await Box(x: 10, y: 10, z: 10).node.isEmpty == false)
        #expect(try await Box(x: 10, y: 10, z: 10).measurements.isEmpty == false)
    }

    @Test func `rectangle with a zero or negative dimension is empty`() async throws {
        #expect(Rectangle(x: 0, y: 10).area == 0)
        #expect(Rectangle(x: -5, y: 10).area == 0)
        #expect(Rectangle(-5).area == 0)
        #expect(try await Rectangle(x: 0, y: 10).node.isEmpty)
        #expect(try await Rectangle(x: 0, y: 10).measurements.isEmpty)
        #expect(try await Rectangle(x: -5, y: 10).node.isEmpty)
        #expect(try await Rectangle(x: -5, y: 10).measurements.isEmpty)
        #expect(try await Rectangle(-5).node.isEmpty)
    }

    @Test func `cylinder with non-positive radius or height is empty`() async throws {
        #expect(try await Cylinder(radius: 0, height: 5).node.isEmpty)
        #expect(try await Cylinder(radius: 0, height: 5).measurements.isEmpty)
        #expect(try await Cylinder(radius: -5, height: 5).node.isEmpty)
        #expect(try await Cylinder(radius: -5, height: 5).measurements.isEmpty)
        #expect(try await Cylinder(radius: 5, height: -5).node.isEmpty)
        #expect(try await Cylinder(radius: 5, height: -5).measurements.isEmpty)
        #expect(try await Cylinder(radius: 5, height: 0).node.isEmpty)
        #expect(try await Cylinder(bottomRadius: 0, topRadius: 0, height: 5).node.isEmpty)
        #expect(try await Cylinder(bottomRadius: 0, topRadius: 0, height: 5).measurements.isEmpty)
        #expect(try await Cylinder(radius: 5, height: 5).node.isEmpty == false)
        #expect(try await Cylinder(radius: 5, height: 5).measurements.isEmpty == false)
    }

    @Test func `stadium with a zero or negative dimension is empty`() async throws {
        #expect(Stadium(x: 0, y: 10).area == 0)
        #expect(Stadium(x: -10, y: 10).area == 0)
        #expect(try await Stadium(x: 0, y: 10).node.isEmpty)
        #expect(try await Stadium(x: 0, y: 10).measurements.isEmpty)
        #expect(try await Stadium(x: -10, y: 10).node.isEmpty)
        #expect(try await Stadium(x: -10, y: 10).measurements.isEmpty)
    }

    @Test func `arc with zero or negative radius is empty`() async throws {
        #expect(Arc(range: 0°..<90°, radius: 0).area == 0)
        #expect(Arc(range: 0°..<90°, radius: -5).area == 0)
        #expect(Arc(range: 0°..<90°, diameter: -10).area == 0)
        #expect(try await Arc(range: 0°..<90°, radius: 0).node.isEmpty)
        #expect(try await Arc(range: 0°..<90°, radius: 0).measurements.isEmpty)
        #expect(try await Arc(range: 0°..<90°, radius: -5).node.isEmpty)
        #expect(try await Arc(range: 0°..<90°, radius: -5).measurements.isEmpty)
        #expect(try await Arc(range: 0°..<90°, diameter: -10).node.isEmpty)
        #expect(try await Arc(range: 0°..<90°, radius: 5).node.isEmpty == false)
        #expect(try await Arc(range: 0°..<90°, radius: 5).measurements.isEmpty == false)
    }
}
