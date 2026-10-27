import Testing
@testable import Cadova

struct EdgeProfileOverhangFilletTests {
    // Regression test for a bug where `overhangFillet` silently fell back to a plain `fillet`:
    // `naturalUpDirection` couldn't be resolved from within the profile's own 2D-then-extruded
    // geometry (the 3D rotation that places it on a specific box edge happens outside that
    // geometry entirely), and `operation` was inverted twice by the two nested `subtracting`
    // calls involved in applying an edge profile, landing back on whatever it started as. Both
    // silently disabled the relief instead of erroring, so the two profiles produced bit-identical
    // geometry with no test ever catching it.
    //
    // Comparing the raw 2D profiles' areas (rather than extruded/boolean 3D volumes) isolates the
    // relief itself from unrelated tessellation differences between `Circle` and `FilletCorner`'s
    // independent implementations, which can otherwise make an unmodified `overhangFillet` profile
    // measure as *slightly* different from a plain fillet even when the relief was never applied.
    //
    // The comparison direction is the one that might seem backwards at first: `.bridge` relief is
    // the convex hull of the circle plus a point above it, clipped back down to the circle's own
    // bounding square. That's a strict superset of the plain circle (the hull's tangent lines bulge
    // outside the circle's arc on their way to the added point, and clipping to the bounding square
    // — which the plain circle already fits inside exactly — never cuts back into the circle
    // itself), so the profile keeps *more* material than a plain fillet, as a support shoulder under
    // the overhang-critical part of the curve.
    @Test func `overhang fillet profile has more area than a plain fillet profile`() async throws {
        let radius = 3.0

        let (plainArea, overhangSafeArea) = try await ModelFileGenerator.evaluate { evaluator in
            (
                await evaluator.measurements(of: EdgeProfile.fillet(radius: radius).profile).area,
                await evaluator.measurements(of: EdgeProfile.overhangFillet(radius: radius).profile).area
            )
        }

        // Sanity: both are still bounded by the profile's own radius × radius square.
        #expect(plainArea <= radius * radius)
        #expect(overhangSafeArea <= radius * radius)

        // The overhang-safe variant must keep strictly more material (a support shoulder) than a
        // plain fillet of the same radius — if it doesn't, the relief silently isn't being applied.
        #expect(overhangSafeArea > plainArea)
    }

    // A self-referential check (comparing the profile against itself under two environments,
    // rather than against a separately-implemented shape) for the same bug: with the relief
    // disabled, changing `overhangAngle` has no effect at all, so this fails exactly the way the
    // bug did — both areas coming out identical — without depending on any other profile type.
    @Test func `overhang fillet respects a tighter overhang angle`() async throws {
        let radius = 3.0
        let profiled = Box(x: 20, y: 20, z: 10).cuttingEdgeProfile(.overhangFillet(radius: radius), on: .bottom)

        let (permissiveVolume, strictVolume) = try await ModelFileGenerator.evaluate { evaluator in
            (
                await evaluator.measurements(of: profiled.withOverhangAngle(70°)).volume,
                await evaluator.measurements(of: profiled.withOverhangAngle(20°)).volume
            )
        }

        // A stricter (smaller) overhang angle demands a bigger support shoulder, keeping more material.
        #expect(strictVolume > permissiveVolume)
    }
}
