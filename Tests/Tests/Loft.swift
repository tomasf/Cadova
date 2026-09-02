import Foundation
import Testing
@testable import Cadova

struct LoftTests {
    @Test func `loft with three sections and holes produces correct geometry`() async throws {
        let loft = Loft {
            Section(at: 0) {
                Circle(diameter: 20)
                    .subtracting {
                        Circle(diameter: 12)
                    }
            }
            Section(at: 30) {
                Rectangle(x: 25, y: 6)
                    .aligned(at: .center)
                    .repeated(in: 0°..<180°, count: 2)
                    .subtracting {
                        RegularPolygon(sideCount: 8, circumradius: 2)
                    }
            }
            Section(at: 35) {
                Circle(diameter: 12)
                    .subtracting {
                        Circle(diameter: 10)
                    }
            }
        }

        try await loft.writeVerificationModel(name: "loftThreeLayers")
        let m = try await loft.measurements

        // Adaptive subdivision places rings by how far the surface would stray without them, so the
        // exact triangulation — and with it the last digits of volume and area — depends on where
        // those rings land. Building this same loft under fixed segmentation, which doesn't go
        // through the adaptive criterion at all, spans 7850.1…7862.0 in volume and 3791.4…3793.9 in
        // area from 64 to 1024 segments, so the value below is inside that bracket rather than at
        // its edge. It is bit-identical over three separate processes, so it is pinned at the same
        // tolerances as the two lofts below rather than loosely: a tolerance wide enough to admit
        // the value this test carried before the change would not be pinning the change at all.
        #expect(m.volume.equals(7853.271, within: 5e-2))
        #expect(m.surfaceArea.equals(3792.011, within: 1e-2))
        #expect(m.boundingBox ≈ .init(minimum: [-12.5, -12.5, 0], maximum: [12.5, 12.5, 35]))
    }

    @Test func `section can specify custom shaping function`() async throws {
        let loft = Loft {
            Section(at: 0) {
                Circle(diameter: 5)
            }
            Section(at: 5) {
                Circle(diameter: 12)
            }
            Section(at: 15, interpolation: .circularEaseOut) {
                Circle(diameter: 20)
            }
            Section(at: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShaping")
        let m = try await loft.measurements

        // Manifold simplification produces slightly different floating-point results across platforms,
        // and adaptive subdivision decides where the rings go, so both are pinned loosely. Fixed
        // segmentation from 128 to 1024 segments puts this shape at 3864.0…3864.7 in volume and
        // 1236.9…1237.2 in area.
        #expect(m.volume.equals(3864.48, within: 5e-2))
        #expect(m.surfaceArea.equals(1237.073, within: 1e-2))
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }

    @Test func `section shaping overrides loft default shaping`() async throws {
        let loft = Loft(interpolation: .smoothstep) {
            Section(at: 0) {
                Circle(diameter: 5)
            }
            Section(at: 5, interpolation: .linear) {
                Circle(diameter: 12)
            }
            Section(at: 15, interpolation: .circularEaseIn) {
                Circle(diameter: 20)
            }
            Section(at: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShapingWithDefault")
        let m = try await loft.measurements

        // Manifold simplification produces slightly different floating-point results across platforms,
        // and adaptive subdivision decides where the rings go, so both are pinned loosely. Fixed
        // segmentation from 128 to 1024 segments puts this shape at 2732.4…2733.4 in volume and
        // 1117.8…1118.4 in area.
        #expect(m.volume.equals(2732.606, within: 5e-2))
        #expect(m.surfaceArea.equals(1117.979, within: 1e-2))
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }

    @Test func `convex hull transition creates hull between sections`() async throws {
        let loft = Loft {
            Section(at: 0) {
                Circle(diameter: 20)
            }
            Section(at: 10, interpolation: .convexHull) {
                Rectangle([10, 10])
                    .aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftConvexHull")
        let m = try await loft.measurements

        // The convex hull of a circle at distance 0 and a square at distance 10
        // should produce a solid that's larger than a simple loft
        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        #expect(m.boundingBox ≈ .init(minimum: [-10, -10, 0], maximum: [10, 10, 10]))
    }

    @Test func `mixed interpolation and convex hull transitions work together`() async throws {
        let loft = Loft {
            Section(at: 0) {
                Circle(diameter: 10)
            }
            Section(at: 10) {
                Circle(diameter: 20)
            }
            Section(at: 20, interpolation: .convexHull) {
                Rectangle([8, 8])
                    .aligned(at: .center)
            }
            Section(at: 30) {
                Rectangle([15, 15])
                    .aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftMixedTransitions")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // Bounding box should span from the circle at bottom to rectangle at top
        #expect(m.boundingBox ≈ .init(minimum: [-10, -10, 0], maximum: [10, 10, 30]))
    }

    @Test func `linear loft between similar triangles preserves corners`() async throws {
        let loft = Loft(interpolation: .linear) {
            Section(at: 0) {
                Triangle(a: 2, b: 2, includedGamma: 90°)
            }
            Section(at: 30) {
                Triangle(a: 5, b: 5, includedGamma: 90°)
            }
        }

        try await loft.writeVerificationModel(name: "loftLinearTriangles")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // With corners preserved, the loft reaches exactly to the outer vertices of the top triangle.
        // Triangle(a:5, b:5, includedGamma:90°) places B at (5√2, 0) and C at (5/√2, 5/√2).
        #expect(m.boundingBox ≈ .init(minimum: [0, 0, 0], maximum: [5 * 2.squareRoot(), 5 / 2.squareRoot(), 30]))
    }

    @Test func `loft between rectangles preserves corners`() async throws {
        let loft = Loft(interpolation: .linear) {
            Section(at: 0) {
                Rectangle([4, 6]).aligned(at: .center)
            }
            Section(at: 20) {
                Rectangle([10, 8]).aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftRectangles")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // Corners of the top rectangle are at exactly ±5 and ±4
        #expect(m.boundingBox ≈ .init(minimum: [-5, -4, 0], maximum: [5, 4, 20]))
    }

    // MARK: - Path-based lofting

    @Test func `loft along a straight non-Z path is positioned and oriented by arc length`() async throws {
        // A path along +X (not Z). `Section(at:)` values are arc-length distances, so `at: 40`
        // lands exactly at the path's end regardless of the curve's own parameterization.
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0]])
        let loft = Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
            Section(at: 0) {
                Circle(diameter: 12)
            }
            Section(at: 40) {
                Circle(diameter: 12)
            }
        }

        try await loft.writeVerificationModel(name: "loftAlongStraightXPath")
        let m = try await loft.measurements

        // Identical cross-sections along a straight path produce a plain cylinder, oriented so the
        // path's tangent (+X) becomes the cylinder's axis.
        #expect(m.boundingBox ≈ .init(minimum: [0, -6, -6], maximum: [40, 6, 6]))
    }

    @Test func `loft extends a too-short path to reach all sections`() async throws {
        let path = BezierPath3D(from: [0, 0, 0]) {
            line(x: 0, y: 0, z: 20)
        }
        let loft = Loft(along: path, pointing: .down, toward: .direction(.negativeZ)) {
            Section(at: 0) { Circle(diameter: 20) }
            Section(at: 40) { Rectangle(20).aligned(at: .center) }
        }

        let m = try await loft.measurements

        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 40]), within: 1e-2) == true)
    }

    @Test func `identical shapes with a twisting target are still subdivided between sections`() async throws {
        // A skew line (not parallel to the implicit vertical path, not passing through it) makes the
        // target direction rotate as height increases, so these two IDENTICALLY-shaped sections still
        // need intermediate subdivision to render the twist between them correctly. Regression test for
        // a bug where "identical 2D shape between sections" incorrectly skipped subdivision outright,
        // ignoring that the orientation (not just the shape) had changed, producing a mesh that cut
        // straight across the twist instead of following it.
        // The plain (no along:) initializer no longer accepts pointing/toward — it always produces an
        // untwisted stack. An explicit vertical path (matching the section range exactly) reproduces the
        // same "stack in Z but track an off-axis target" behavior via the along: initializer instead.
        let skewLine = D3.Line(point: [5, 0, 0], direction: Direction3D(x: 1, y: 1, z: 1))
        let verticalPath = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 40]])
        let loft = Loft(along: verticalPath, pointing: .negativeY, toward: .line(skewLine)) {
            Section(at: 0) { Rectangle(x: 10, y: 4).aligned(at: .center) }
            Section(at: 40) { Rectangle(x: 10, y: 4).aligned(at: .center) }
        }

        try await loft.writeVerificationModel(name: "loftTwistWithIdenticalShapes")
        let m = try await loft.measurements

        // A twisted prism with constant 10x4 cross-section should retain close to its untwisted
        // volume (1600) when properly subdivided. The unfixed bug undercounted this substantially
        // (collapsing straight across the twist instead of following it).
        #expect(m.volume.equals(1600, within: 1))
    }

    @Test func `loft along a path orients cross-sections using pointing and toward`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0]])
        let loft = Loft(along: path, pointing: .negativeY, toward: .direction(.up)) {
            Section(at: 0) {
                Rectangle(x: 10, y: 4).aligned(at: .center)
            }
            Section(at: 40) {
                Rectangle(x: 10, y: 4).aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftAlongPathWithOrientation")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        #expect(m.boundingBox ≈ .init(minimum: [0, -5, -2], maximum: [40, 5, 2]))
    }

    @Test func `loft along a curved 3D path produces valid geometry that follows the bend`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 20], [20, 0, 20]])
        let loft = Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
            Section(at: 0) {
                Circle(diameter: 8)
            }
            Section(at: 40) {
                Circle(diameter: 8)
            }
        }

        try await loft.writeVerificationModel(name: "loftAlongBentPath")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // The loft should follow the bend: it must extend along both Z (first leg) and X (second leg),
        // unlike a Z-only loft which would have zero X extent.
        #expect(m.boundingBox!.size.x > 1)
        #expect(m.boundingBox!.size.z > 1)
    }

    @Test func `sharp corner is mitered instead of squished`() async throws {
        // Regression test for a bug where sharp corners had no miter frame at all, connecting
        // perpendicular-to-incoming and perpendicular-to-outgoing cross-sections directly and squishing
        // the corner. The smoothed miter transition intentionally interpolates into the miter frame
        // instead of cutting in one hard slice, so guard against both the original collapse (~75% of
        // this nominal volume for a 90° bend) and excessive inflation.
        let diameter = 16.0
        let area = Double.pi * (diameter / 2) * (diameter / 2)
        let start = Vector3D(0, 0, 0), corner = Vector3D(0, 0, 40), end = Vector3D(40, 0, 40)
        let expectedVolume = area * ((corner - start).magnitude + (end - corner).magnitude)

        let path = BezierPath3D(linesBetween: [start, corner, end])
        let loft = Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
            Section(at: 0) { Circle(diameter: diameter) }
            Section(at: (corner - start).magnitude + (end - corner).magnitude) { Circle(diameter: diameter) }
        }

        try await loft.writeVerificationModel(name: "loftMiteredCorner")
        let m = try await loft.measurements
        #expect(m.volume > expectedVolume * 0.85)
        #expect(m.volume < expectedVolume * 1.1)
    }

    // MARK: - Orientation-dependent sections

    @Test func `overhangSafe follows each section's own orientation along the path`() async throws {
        // A loft along a horizontal path stands its cross-sections upright in space, so "up" is a real
        // direction within a section's own 2D plane and overhangSafe must act on it. It used to be a
        // silent no-op, because sections were built in the ambient environment (up = world +Z, which has
        // no projection onto a section's plane) rather than in the frame they're actually placed at.
        let radius = 6.0
        let negativeRadius = -radius
        // The additive teardrop's apex sits radius / sin(overhangAngle) from the center, pointing
        // opposite the up direction: a downward spike grows at a printable angle, a circle's underside
        // doesn't. With the default 45° overhang angle that's radius * √2 below the path.
        let expectedApexZ = -radius / sin(45°)
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0]])

        let plainLoft = Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
            Section(at: 0) { Circle(radius: radius) }
            Section(at: 40) { Circle(radius: radius) }
        }
        let overhangSafeLoft = Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
            Section(at: 0) { Circle(radius: radius).overhangSafe(.teardrop) }
            Section(at: 40) { Circle(radius: radius).overhangSafe(.teardrop) }
        }

        try await overhangSafeLoft.writeVerificationModel(name: "loftOverhangSafeAlongPath")
        let plain = try await plainLoft.measurements
        let overhangSafe = try await overhangSafeLoft.measurements
        let plainBox = try #require(plain.boundingBox)
        let overhangSafeBox = try #require(overhangSafe.boundingBox)

        // The control stays a plain cylinder lying along +X.
        #expect(plainBox.minimum.z.equals(negativeRadius, within: 1e-2))
        #expect(plainBox.maximum.z.equals(radius, within: 1e-2))

        // The teardrop reaches its analytic apex below the path while its top stays a circle.
        // The tolerance absorbs resampling, which doesn't necessarily land a vertex on the sharp tip.
        #expect(overhangSafeBox.minimum.z.equals(expectedApexZ, within: 0.15))
        #expect(overhangSafeBox.maximum.z.equals(radius, within: 1e-2))
        #expect(overhangSafe.volume > plain.volume)
    }

    @Test func `overhangSafe stays inert in a vertical loft`() async throws {
        // The sections of a plain (vertical) loft lie flat, perpendicular to the up direction, so there
        // is no overhang to compensate for and overhangSafe must leave them alone.
        let radius = 6.0
        let plainLoft = Loft {
            Section(at: 0) { Circle(radius: radius) }
            Section(at: 20) { Circle(radius: radius) }
        }
        let overhangSafeLoft = Loft {
            Section(at: 0) { Circle(radius: radius).overhangSafe(.teardrop) }
            Section(at: 20) { Circle(radius: radius).overhangSafe(.teardrop) }
        }

        let plain = try await plainLoft.measurements
        let overhangSafe = try await overhangSafeLoft.measurements

        #expect(overhangSafe.volume ≈ plain.volume)
        #expect(overhangSafe.surfaceArea ≈ plain.surfaceArea)
        #expect(overhangSafe.boundingBox == plain.boundingBox)
    }

    @Test func `Section supports a distance range for a straight run of unchanging shape`() async throws {
        let loft = Loft {
            Section(at: 0) { Circle(diameter: 10) }
            Section(at: 10..<20) { Circle(diameter: 20) }
            Section(at: 30) { Circle(diameter: 10) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 20, 30])

        try await loft.writeVerificationModel(name: "loftSectionRange")
        let m = try await loft.measurements

        // A straight (unchanging) run between distance 10 and 20 means the widest cross-section
        // (diameter 20) should persist unchanged across that whole span, not taper immediately.
        // (Circle polygon approximation means the bounds are very slightly inside the true radius.)
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 30]), within: 1e-2) == true)
    }

    @Test func `Section supports atRelative offsets and offset ranges`() async throws {
        let loft = Loft {
            Section(at: 0) { Circle(diameter: 5) }
            Section(atRelative: 10) { Circle(diameter: 5) }
            Section(atRelative: 5..<15) { Circle(diameter: 5) }
            Section(atRelative: 3) { Circle(diameter: 5) }
        }
        // 0, then +10 -> 10, then +5..<15 relative to the *previous* (10) -> 15, 25, then +3 from 25 -> 28
        #expect(loft.sections.map(\.distance) == [0, 10, 15, 25, 28])
    }

    // MARK: - Deprecated API compatibility

    @available(*, deprecated)
    @Test func `deprecated layer API produces identical geometry to Section`() async throws {
        let deprecatedLoft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10) { Circle(diameter: 12) }
            layer(z: 25) { Circle(diameter: 8) }
        }
        let newLoft = Loft {
            Section(at: 0) { Circle(diameter: 5) }
            Section(at: 10) { Circle(diameter: 12) }
            Section(at: 25) { Circle(diameter: 8) }
        }

        let deprecatedMeasurements = try await deprecatedLoft.measurements
        let newMeasurements = try await newLoft.measurements

        #expect(deprecatedMeasurements.volume ≈ newMeasurements.volume)
        #expect(deprecatedMeasurements.surfaceArea ≈ newMeasurements.surfaceArea)
        #expect(deprecatedMeasurements.boundingBox == newMeasurements.boundingBox)
    }

    // MARK: - Section resolution

    @available(*, deprecated)
    @Test func `absolute layers resolve to correct Z positions`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10) { Circle(diameter: 5) }
            layer(z: 25) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 25])
    }

    @available(*, deprecated)
    @Test func `offset layers resolve relative to previous layer`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 15])
    }

    @available(*, deprecated)
    @Test func `absolute range creates two layers at bounds`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 5..<15) { Circle(diameter: 5) }
            layer(z: 20) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 5, 15, 20])
    }

    @available(*, deprecated)
    @Test func `offset range creates two layers relative to previous`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 5..<15) { Circle(diameter: 5) }
            layer(zOffset: 3) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 5, 15, 18])
    }

    @available(*, deprecated)
    @Test func `mixed absolute and offset layers resolve correctly`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10) { Circle(diameter: 5) }
            layer(z: 30) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 30, 35])
    }

    @available(*, deprecated)
    @Test func `out-of-order absolute layers are sorted by Z`() {
        let loft = Loft {
            layer(z: 20) { Circle(diameter: 5) }
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 20])
    }

    @available(*, deprecated)
    @Test func `offset after absolute range starts from range upper bound`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10..<20) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 20, 25])
    }

    @available(*, deprecated)
    @Test func `offset after offset range starts from range upper bound`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10..<20) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.sections.map(\.distance) == [0, 10, 20, 25])
    }

    // MARK: - Geometry

    @Test func `visualized loft shows sections at correct positions`() async throws {
        let loft = Loft {
            Section(at: 0) {
                Circle(diameter: 20)
            }
            Section(at: 10) {
                Rectangle([15, 15])
                    .aligned(at: .center)
            }
            Section(at: 25) {
                Circle(diameter: 10)
            }
        }

        let visualization = loft.visualized()
        try await visualization.writeVerificationModel(name: "loftVisualized")
        let m = try await visualization.measurements(for: .allParts)

        // The visualization should span approximately from z=0 to z=25
        #expect(m.boundingBox!.minimum.z ≈ 0)
        #expect(m.boundingBox!.maximum.z ≈ 25)
        // Should have some volume (the extruded section slabs)
        #expect(m.volume > 0)
    }
}
