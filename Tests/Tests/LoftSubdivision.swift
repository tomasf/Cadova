import Foundation
import Testing
@testable import Cadova

/// Covers how densely `Loft` samples the surface between two sections.
///
/// The criterion has to be an *accuracy* test, not a *spacing* test: it must insert a ring only when
/// leaving it out would move the surface, and it must insert one whenever leaving it out would. The
/// first half of this suite drives `interpolatePolygonGroups` directly and counts the rings it asks
/// for, once per branch of the criterion. The second half meshes the same shapes at the default
/// segmentation and compares them against a deliberately over-refined reference, so a criterion that
/// bought its ring count by losing fidelity fails here rather than passing quietly.
struct LoftSubdivisionTests {
    // A segmentation fine enough that its own error is far below what we're measuring, used to build
    // the reference each fixed-resolution loft is compared against. Both `minAngle` and `minSize` are
    // tightened, since the loft's ring resolution comes from `minSize` and its along-path resolution
    // from both.
    static let referenceSegmentation = Segmentation.adaptive(minAngle: 0.5°, minSize: 0.05)

    static func polygonCircle(radius: Double, count: Int) -> SimplePolygon {
        SimplePolygon((0..<count).map {
            let angle = Double($0) / Double(count) * 360°
            return Vector2D(cos(angle) * radius, sin(angle) * radius)
        })
    }

    /// Runs the subdivision recursion on its own and returns the rings it produced, so a test can
    /// count them without paying for a mesh.
    static func rings(
        from lower: SimplePolygon,
        to upper: SimplePolygon,
        along path: BezierPath3D,
        distance: Double,
        interpolation: ShapingFunction = .linear,
        pointing reference: Direction2D = .negativeY,
        toward target: ReferenceTarget = .direction(.negativeY),
        environment: EnvironmentValues = .defaultEnvironment
    ) -> (polygons: SimplePolygonList, transforms: [Transform3D]) {
        let frames = path.frames(
            environment: environment,
            target: target,
            targetReference: reference,
            perpendicularBounds: .init(minimum: [-50, -50], maximum: [50, 50]),
            miteringCorners: true
        )
        let sections = [
            Loft.ResamplingSection(distance: 0, transition: .interpolated(.linear), tree: .empty),
            Loft.ResamplingSection(distance: distance, transition: .interpolated(interpolation), tree: .empty),
        ]
        return Loft.interpolatePolygonGroups(
            for: [SimplePolygonList([lower, upper])],
            sections: sections,
            frames: frames,
            curve: path,
            reference: reference,
            target: target,
            environment: environment
        )[0]
    }

    static let verticalPath = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 100]])

    /// A shaping function that rises overall but ripples on the way, so the surface between two
    /// sections gains `waves` bulges instead of running straight.
    ///
    /// This is the family that catches a criterion which samples at fixed fractions. A whole number
    /// of waves puts a zero crossing on every dyadic fraction at once, so the deviation from the
    /// chord vanishes at a quarter, a half and three quarters together, and a test that only looks
    /// there reads the whole thing as flat.
    static func ripple(waves: Double, phase: Double = 0, amplitude: Double = 0.15) -> ShapingFunction {
        .custom(name: "ripple", parameters: waves, phase, amplitude) { t in
            t + amplitude * sin((waves * t + phase) * 2 * .pi)
        }
    }

    static func rippleRings(waves: Double, phase: Double = 0) -> Int {
        rings(
            from: polygonCircle(radius: 25, count: 128),
            to: polygonCircle(radius: 8, count: 128),
            along: verticalPath,
            distance: 100,
            interpolation: ripple(waves: waves, phase: phase)
        ).transforms.count
    }

    // MARK: - How many rings the criterion asks for

    @Test func `linear shaping along a straight path needs no intermediate rings`() throws {
        // With `.linear` shaping and an unchanging frame, the ring at any t is exactly
        // lerp(lower, upper, t): every intermediate ring lands on the ruled surface the two bracketing
        // rings already span, so every one of them is pure cost. The criterion must notice that and
        // emit the two section rings and nothing else.
        let result = Self.rings(
            from: Self.polygonCircle(radius: 10, count: 256),
            to: Self.polygonCircle(radius: 20, count: 256),
            along: Self.verticalPath,
            distance: 100
        )
        #expect(result.transforms.count == 2)
    }

    @Test func `a nonlinear shaping function is still subdivided`() throws {
        // `.circularEaseOut` bulges away from the straight blend, so the surface genuinely curves
        // between the two sections and rings have to be inserted to follow it.
        let result = Self.rings(
            from: Self.polygonCircle(radius: 10, count: 256),
            to: Self.polygonCircle(radius: 20, count: 256),
            along: Self.verticalPath,
            distance: 100,
            interpolation: .circularEaseOut
        )
        // Measured at 166 rings. The upper bound matters as much as the lower one:
        // without it, an implementation that recursed to `maximumSubdivisionDepth` on every span
        // would pass, and spending rings is the very thing this criterion exists to stop.
        #expect((20..<400).contains(result.transforms.count))
    }

    @Test func `a shaping function that is symmetric about its own midpoint is still subdivided`() throws {
        // `.smoothstep` (like `.sine`, `.easeInOut` and `.smootherstep`) passes exactly through the
        // midpoint of its own chord: f(0.5) == 0.5. A deviation test that only ever samples the
        // midpoint therefore measures zero error for it and collapses the whole S-curve into one
        // straight band. The criterion has to look somewhere other than the midpoint too.
        let result = Self.rings(
            from: Self.polygonCircle(radius: 10, count: 256),
            to: Self.polygonCircle(radius: 20, count: 256),
            along: Self.verticalPath,
            distance: 100,
            interpolation: .smoothstep
        )
        // Measured at 105 rings. The upper bound matters as much as the lower one:
        // without it, an implementation that recursed to `maximumSubdivisionDepth` on every span
        // would pass, and spending rings is the very thing this criterion exists to stop.
        #expect((20..<300).contains(result.transforms.count))
    }

    @Test func `a rippling shaping function is subdivided at every wave count`() throws {
        // The criterion may not measure the surface at fractions fixed in advance. A whole number of
        // waves lands a zero of the chord deviation on all of a quarter, a half and three quarters at
        // once, so a test that samples only there reports no error and collapses the ripples into a
        // plain cone. Every one of these wave counts did exactly that before the probe was added:
        // 1 and 3 were subdivided, while 2, 4, 8, 16, 20 and 32 came out at two rings.
        //
        // The bounds are per wave, since a ripple genuinely needs rings in proportion to how many
        // bulges it has. The lower one has teeth against the collapse; the upper one against an
        // implementation that recurses to `maximumSubdivisionDepth` and calls it accuracy.
        for waves in [1.0, 2, 3, 4, 8, 16, 20, 32] {
            let count = Self.rippleRings(waves: waves)
            #expect(
                (Int(20 * waves)..<Int(400 * waves)).contains(count),
                "\(waves) waves produced \(count) rings"
            )
        }
    }

    @Test func `the ring count for a rippling shaping function grows with the wave count`() throws {
        // Subdividing every ripple is not enough on its own: an implementation could pass the test
        // above by splitting blindly. Following the shape means paying for the bulges that are
        // actually there, so twice the waves has to cost meaningfully more than half as many.
        let two = Self.rippleRings(waves: 2)
        let four = Self.rippleRings(waves: 4)
        let eight = Self.rippleRings(waves: 8)
        #expect(four > two)
        #expect(eight > four)
    }

    @Test func `a rippling shaping function is subdivided off the dyadic fractions too`() throws {
        // Nothing about the fix may depend on the waves lining up with the sample fractions. A wave
        // count just off a whole number, and a whole one shifted in phase, both have to come out in
        // the same range as the aligned counts above, not merely be caught by luck.
        for waves in [2.001, 3.5, 4.25] {
            let count = Self.rippleRings(waves: waves)
            #expect((Int(20 * waves)..<Int(400 * waves)).contains(count), "\(waves) waves gave \(count) rings")
        }
        for phase in [0.125, 0.25, 0.5] {
            let count = Self.rippleRings(waves: 4, phase: phase)
            #expect((80..<1600).contains(count), "phase \(phase) gave \(count) rings")
        }
    }

    @Test func `a shaping function whose waves speed up along the loft is subdivided`() throws {
        // A chirp has no single wave count to line up with anything, and its bulges are wide at one
        // end and narrow at the other. The criterion has to keep finding them as they tighten, which
        // a search over the shape does and a fixed set of fractions cannot.
        let chirp = ShapingFunction.custom(name: "chirp", parameters: 0) { t in
            t + 0.1 * sin(2 * .pi * (2 * t + 6 * t * t))
        }
        let count = Self.rings(
            from: Self.polygonCircle(radius: 25, count: 128),
            to: Self.polygonCircle(radius: 8, count: 128),
            along: Self.verticalPath,
            distance: 100,
            interpolation: chirp
        ).transforms.count
        #expect((200..<6000).contains(count), "chirp gave \(count) rings")
    }

    @Test func `a twisting path is still subdivided`() throws {
        // Identical rings, straight path — but a skew target line rotates the frame as the loft rises,
        // so a straight band between the end rings would cut across the twist.
        let skewLine = D3.Line(point: [5, 0, 0], direction: Direction3D(x: 1, y: 1, z: 1))
        let square = SimplePolygon([[-5, -2], [5, -2], [5, 2], [-5, 2]]).resampled(count: 64)
        let result = Self.rings(
            from: square,
            to: square,
            along: Self.verticalPath,
            distance: 100,
            toward: .line(skewLine)
        )
        // Measured at 127 rings, up from 78 before the warp test stopped exempting bands shorter than
        // their own rings' edges: a twist is exactly the case where a band is sheared, so this is the
        // shape that exemption was quietly costing. The upper bound matters as much as the lower one:
        // without it, an implementation that recursed to `maximumSubdivisionDepth` on every span
        // would pass, and spending rings is the very thing this criterion exists to stop.
        #expect((20..<200).contains(result.transforms.count))
    }

    @Test func `a curving path is still subdivided`() throws {
        let path = BezierPath3D(from: [0, 0, 0]) {
            curve(controlX: 0, controlY: 0, controlZ: 30, endX: 30, endY: 0, endZ: 30)
        }
        let circle = Self.polygonCircle(radius: 6, count: 128)
        let result = Self.rings(from: circle, to: circle, along: path, distance: 40)
        // Measured at 192 rings. The upper bound matters as much as the lower one:
        // without it, an implementation that recursed to `maximumSubdivisionDepth` on every span
        // would pass, and spending rings is the very thing this criterion exists to stop.
        #expect((20..<500).contains(result.transforms.count))
    }

    @Test func `the ring count for a straight linear loft does not grow with its length`() throws {
        // A spacing criterion scales the ring count with the loft's length; an accuracy criterion
        // doesn't, because a longer ruled surface is no less exactly ruled.
        let short = Self.rings(
            from: Self.polygonCircle(radius: 10, count: 256),
            to: Self.polygonCircle(radius: 20, count: 256),
            along: BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 10]]),
            distance: 10
        )
        let long = Self.rings(
            from: Self.polygonCircle(radius: 10, count: 256),
            to: Self.polygonCircle(radius: 20, count: 256),
            along: BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 1000]]),
            distance: 1000
        )
        #expect(short.transforms.count == long.transforms.count)
    }

    @Test func `rings are never emitted on top of each other`() throws {
        // Subdivision no longer stops at a fixed path spacing, so the recursion has to bottom out on
        // its own before it starts emitting duplicate rings, which would make degenerate triangles.
        let result = Self.rings(
            from: Self.polygonCircle(radius: 3, count: 128),
            to: Self.polygonCircle(radius: 12, count: 128),
            along: Self.verticalPath,
            distance: 100,
            interpolation: .circularEaseOut
        )
        for (previous, next) in result.transforms.map(\.offset).paired() {
            #expect(previous.distance(to: next) > 1e-6)
        }
    }

    // MARK: - Fidelity against an over-refined reference

    /// Builds the same loft twice — once at the default segmentation, once at a much finer one — and
    /// checks that the coarser one still describes the same solid.
    static func expectMatchesFineReference(
        _ geometry: any Geometry3D,
        volumeTolerance: Double,
        areaTolerance: Double,
        boundsTolerance: Double = 1e-2,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let actual = try await geometry.measurements
        let reference = try await geometry.withSegmentation(referenceSegmentation).measurements

        let actualVolume = await actual.volume
        let referenceVolume = await reference.volume
        let actualSurfaceArea = await actual.surfaceArea
        let referenceSurfaceArea = await reference.surfaceArea
        let volumeError = abs(actualVolume - referenceVolume) / referenceVolume
        let areaError = abs(actualSurfaceArea - referenceSurfaceArea) / referenceSurfaceArea
        #expect(volumeError < volumeTolerance, "relative volume error \(volumeError)", sourceLocation: sourceLocation)
        #expect(areaError < areaTolerance, "relative surface area error \(areaError)", sourceLocation: sourceLocation)

        let actualBox = try #require(actual.boundingBox, sourceLocation: sourceLocation)
        let referenceBox = try #require(reference.boundingBox, sourceLocation: sourceLocation)
        #expect(actualBox.equals(referenceBox, within: boundsTolerance), sourceLocation: sourceLocation)
    }

    @Test func `a straight linear cone matches its analytic volume and a fine reference`() async throws {
        let bottomRadius = 10.0
        let topRadius = 20.0
        let height = 100.0
        let loft = Loft {
            Section(at: 0) { Circle(radius: bottomRadius) }
            Section(at: height) { Circle(radius: topRadius) }
        }

        let m = try await loft.measurements
        // A frustum's exact volume. The loft's rings are inscribed polygons rather than true circles,
        // so the mesh sits very slightly inside the analytic solid.
        let analyticVolume = .pi * height
            * (bottomRadius * bottomRadius + bottomRadius * topRadius + topRadius * topRadius) / 3
        let volume = await m.volume
        #expect(abs(volume - analyticVolume) / analyticVolume < 1e-3)

        try await Self.expectMatchesFineReference(loft, volumeTolerance: 1e-3, areaTolerance: 1e-3)
    }

    @Test func `a straight linear cone is no coarser than the equivalent cylinder`() async throws {
        let loft = Loft {
            Section(at: 0) { Circle(radius: 10) }
            Section(at: 100) { Circle(radius: 20) }
        }
        let m = try await loft.measurements

        // The exact solid, built by the primitive that doesn't have to interpolate anything. Both come
        // out at 716 triangles, and both did before this change too, because `.simplified()` already
        // discarded the excess: what the old criterion wasted was time, not output. So this test says
        // nothing about cost, which the ring counts above pin instead. What it does say is that the
        // new criterion has not started emitting a solid the primitive would call over-tessellated.
        let cylinder = Cylinder(bottomRadius: 10, topRadius: 20, height: 100)
        let cylinderTriangles = try await cylinder.measurements.triangleCount
        #expect(m.triangleCount < cylinderTriangles * 2)
    }

    @Test func `a nonlinear shaping function keeps its shape at the default segmentation`() async throws {
        try await Self.expectMatchesFineReference(
            Loft {
                Section(at: 0) { Circle(diameter: 5) }
                Section(at: 5) { Circle(diameter: 12) }
                Section(at: 15, interpolation: .circularEaseOut) { Circle(diameter: 20) }
                Section(at: 20) { Circle(diameter: 10) }
            },
            volumeTolerance: 2e-3,
            areaTolerance: 2e-3
        )
    }

    @Test func `a symmetric shaping function keeps its shape at the default segmentation`() async throws {
        try await Self.expectMatchesFineReference(
            Loft(interpolation: .smoothstep) {
                Section(at: 0) { Circle(diameter: 6) }
                Section(at: 20) { Circle(diameter: 20) }
            },
            volumeTolerance: 2e-3,
            areaTolerance: 2e-3
        )
    }

    @Test func `a curving path keeps its shape at the default segmentation`() async throws {
        let path = BezierPath3D(from: [0, 0, 0]) {
            curve(controlX: 0, controlY: 0, controlZ: 30, endX: 30, endY: 0, endZ: 30)
        }
        try await Self.expectMatchesFineReference(
            Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
                Section(at: 0) { Circle(diameter: 12) }
                Section(at: 40) { Circle(diameter: 12) }
            },
            volumeTolerance: 3e-3,
            areaTolerance: 3e-3,
            boundsTolerance: 0.1
        )
    }

    @Test func `a twisting path keeps its shape at the default segmentation`() async throws {
        let skewLine = D3.Line(point: [5, 0, 0], direction: Direction3D(x: 1, y: 1, z: 1))
        let verticalPath = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 40]])
        let loft = Loft(along: verticalPath, pointing: .negativeY, toward: .line(skewLine)) {
            Section(at: 0) { Rectangle(x: 10, y: 4).aligned(at: .center) }
            Section(at: 40) { Rectangle(x: 10, y: 4).aligned(at: .center) }
        }

        // A twisted prism of constant cross-section keeps its untwisted volume when the twist is
        // followed rather than cut across.
        let m = try await loft.measurements
        let volume = await m.volume
        #expect(volume.equals(1600, within: 1))

        try await Self.expectMatchesFineReference(loft, volumeTolerance: 2e-3, areaTolerance: 3e-3, boundsTolerance: 0.1)
    }

    @Test func `sections with holes and differing vertex counts keep their shape`() async throws {
        try await Self.expectMatchesFineReference(
            Loft {
                Section(at: 0) {
                    Circle(diameter: 20)
                        .subtracting { Circle(diameter: 12) }
                }
                Section(at: 30) {
                    Rectangle(x: 25, y: 6)
                        .aligned(at: .center)
                        .repeated(in: 0°..<180°, count: 2)
                        .subtracting { RegularPolygon(sideCount: 8, circumradius: 2) }
                }
                Section(at: 35) {
                    Circle(diameter: 12)
                        .subtracting { Circle(diameter: 10) }
                }
            },
            volumeTolerance: 5e-3,
            areaTolerance: 5e-3,
            boundsTolerance: 0.1
        )
    }

    @Test func `an overhangSafe loft along a path keeps its shape`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0]])
        try await Self.expectMatchesFineReference(
            Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
                Section(at: 0) { Circle(radius: 6).overhangSafe(.teardrop) }
                Section(at: 40) { Circle(radius: 6).overhangSafe(.teardrop) }
            },
            volumeTolerance: 2e-3,
            areaTolerance: 2e-3,
            boundsTolerance: 0.2
        )
    }

    @Test func `a convex hull transition keeps its shape`() async throws {
        try await Self.expectMatchesFineReference(
            Loft {
                Section(at: 0) { Circle(diameter: 10) }
                Section(at: 10) { Circle(diameter: 20) }
                Section(at: 20, interpolation: .convexHull) { Rectangle([8, 8]).aligned(at: .center) }
                Section(at: 30) { Rectangle([15, 15]).aligned(at: .center) }
            },
            volumeTolerance: 3e-3,
            areaTolerance: 3e-3,
            boundsTolerance: 0.1
        )
    }

    @Test func `a rippling shaping function keeps its bulges at the default segmentation`() async throws {
        // The report this test comes from: a four wave ripple between a wide and a narrow circle came
        // out as a plain truncated cone, with volume and surface area equal to the same loft shaped
        // `.linear`. So the check is against `.linear` as well as against a fine reference. Matching
        // the fine reference alone would not catch it, because a mesh can agree with an over-refined
        // version of the wrong shape.
        let sections = { (interpolation: ShapingFunction) in
            Loft(interpolation: interpolation) {
                Section(at: 0) { Circle(radius: 25) }
                Section(at: 100) { Circle(radius: 8) }
            }
        }
        let rippled = sections(Self.ripple(waves: 4))
        let straight = sections(.linear)

        let rippledMeasurements = try await rippled.measurements
        let straightMeasurements = try await straight.measurements

        // Surface area is the figure that separates the two, at 13640 against 12678. Volume is not,
        // and deliberately is not asserted on: this ripple is symmetric in the blend parameter, so it
        // removes almost exactly as much material as it adds and comes out within 0.06% of the cone
        // either way. That is a property of the shape, not evidence about the mesh, and a volume
        // check here would be a check that passes for the wrong reason.
        let rippledSurfaceArea = await rippledMeasurements.surfaceArea
        let straightSurfaceArea = await straightMeasurements.surfaceArea
        let areaRatio = rippledSurfaceArea / straightSurfaceArea
        #expect(areaRatio > 1.05, "rippled surface area was \(areaRatio) times the cone's")

        // The cone simplifies to 716 triangles and the ripples cannot: measured at 173698 against 716.
        // This is the figure from the report, where the collapsed version came out at 716 as well.
        #expect(
            rippledMeasurements.triangleCount > straightMeasurements.triangleCount * 20,
            "rippled mesh had \(rippledMeasurements.triangleCount) triangles against the cone's \(straightMeasurements.triangleCount)"
        )

        // Measured at 1.1e-4 and 1.4e-4, so this is pinned close rather than merely loosely bracketed.
        try await Self.expectMatchesFineReference(rippled, volumeTolerance: 1e-3, areaTolerance: 1e-3)
    }

    @Test func `a mitered sharp corner keeps its shape`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [0, 0, 40], [40, 0, 40]])
        try await Self.expectMatchesFineReference(
            Loft(along: path, pointing: .negativeY, toward: .direction(.negativeZ)) {
                Section(at: 0) { Circle(diameter: 16) }
                Section(at: 80) { Circle(diameter: 16) }
            },
            volumeTolerance: 5e-3,
            areaTolerance: 5e-3,
            boundsTolerance: 0.2
        )
    }
}
