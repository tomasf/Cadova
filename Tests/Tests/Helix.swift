import Foundation
import Testing
@testable import Cadova

struct HelixTests {
    // Dimensions shared by every case below. The height is a whole number of turns, which keeps the
    // clipping term in the volume below exact.
    //
    // These are radii rather than the diameters the style guide prefers because nothing here takes a
    // diameter: the profile is a rectangle spanning two radii and positioned by one of them, and the
    // enclosed volume is an annulus area. Converting would halve each value straight back at every use.
    static let innerRadius = 8.0
    static let outerRadius = 10.0
    static let profileThickness = 1.0
    static let pitch = 4.0
    static let height = 20.0
    static let turns = height / pitch

    /// Segments per revolution. The facet error in `idealVolume` below is quoted at this count.
    static let segmentCount = 360

    /// The rectangular profile, sitting between the two radii and one `profileThickness` tall.
    static var helix: any Geometry3D {
        Rectangle(x: outerRadius - innerRadius, y: profileThickness)
            .translated(x: innerRadius)
            .sweptAlongHelix(pitch: pitch, height: height)
            .withSegmentation(count: segmentCount)
    }

    // Sweeping along a helix bends a linear prism onto a cylinder: the shape is extruded to one
    // revolution's circumference per turn, its x becomes the radius, its extrusion length becomes the
    // angle, and the result is sheared upward by `pitch` per turn. The Jacobian determinant of that
    // map is x / outerRadius, since the shear contributes nothing to it, so a rectangular profile
    // spanning radii a…b, `t` tall, swept over `n` turns encloses
    //
    //     π (b² - a²) n t
    //
    // before the sweep is clipped to `height`. Clipping at height = n · pitch shaves the top off the
    // last t / pitch of a turn, where the material standing above the plane thins linearly from t to
    // nothing, taking π (b² - a²) t² / (2 pitch) with it.
    //
    // The realized mesh approximates all of that with flat facets and so comes in a little under the
    // ideal figure, hence a relative comparison rather than an exact one.
    static var idealVolume: Double {
        let annulusArea = .pi * (outerRadius * outerRadius - innerRadius * innerRadius)
        let sweptTurns = turns * profileThickness
        let clippedByHeight = profileThickness * profileThickness / (2 * pitch)
        return annulusArea * (sweptTurns - clippedByHeight)
    }

    /// How far under `idealVolume` the faceted mesh is allowed to come in, relative to the ideal.
    /// At `segmentCount` segments per revolution the mesh measures 0.0797% under, bit-identical over
    /// five runs, so this leaves a quarter of that again in headroom and no more.
    static let volumeFacetTolerance = 0.001

    @Test func `helical sweep encloses the volume its geometry implies`() async throws {
        let volume = try await Self.helix.measurements.volume
        #expect(abs(volume - Self.idealVolume) / Self.idealVolume < Self.volumeFacetTolerance)
    }

    @Test func `helical sweep spans its full radius and exactly its requested height`() async throws {
        let bounds = try #require(try await Self.helix.bounds)

        #expect(bounds.minimum ≈ Vector3D(-Self.outerRadius, -Self.outerRadius, 0))
        #expect(bounds.maximum ≈ Vector3D(Self.outerRadius, Self.outerRadius, Self.height))
    }

    @Test(arguments: [0°, 90°, 180°, 270°])
    func `helical sweep is right-handed`(angle: Angle) async throws {
        // A thin radial slab, no taller than a single turn, catches exactly one pass of the sweep. In
        // a right-handed helix that pass sits a quarter of the pitch higher at each quarter turn
        // counter-clockwise; in a left-handed one it would descend instead.
        let expectedRise = Self.pitch * angle.turns

        let slabWidth = 0.2
        // Reach past the outer radius so the slab cuts the whole profile rather than clipping it.
        let slabOvershoot = 1.0
        // Keep the slab shorter than one turn, so it cannot catch a second pass of the sweep.
        let slabHeight = Self.pitch - 0.5

        let wedge = Self.helix.intersecting {
            Box(x: Self.outerRadius + slabOvershoot, y: slabWidth, z: slabHeight)
                .aligned(at: .centerY)
                .rotated(z: angle)
        }

        let bounds = try #require(try await wedge.bounds)
        #expect(abs(bounds.minimum.z - expectedRise) < 0.02)
    }
}
