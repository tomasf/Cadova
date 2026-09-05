import Foundation
import Testing
@testable import Cadova

/// The attraction operations move points toward a target with a strength that depends on how far
/// away they are. Two properties have to hold for that to produce usable geometry:
///
/// * The strength has to *decay* with distance and reach zero *at* the influence radius, so the
///   deformation is continuous across the boundary of the influence sphere. A falloff applied the
///   other way round yanks points just inside the boundary by the full movement while leaving points
///   just outside untouched, which tears the mesh exactly on that sphere.
struct AttractionTests {
    /// The distance a tiny marker cube moves toward the origin when it starts out `distance` away
    /// from it. The marker is small enough that the falloff is effectively constant across it, so
    /// the movement of its bounding box centre is the displacement the deformation applies at that
    /// distance. Simplification is switched off because its default threshold is a quarter of the
    /// marker, large enough to nudge the very bounds being measured.
    private func displacement(
        atDistance distance: Double,
        influenceRadius: Double,
        maxMovement: Double,
        falloff: ShapingFunction? = .smoothstep
    ) async throws -> Double {
        let marker = Box(0.02)
            .aligned(at: .center)
            .translated(x: distance)
            .attracted(toward: .zero, influenceRadius: influenceRadius, maxMovement: maxMovement, falloff: falloff)
            .withSimplificationThreshold(0)
        let bounds = try #require(try await marker.bounds)
        return distance - bounds.center.x
    }

    // MARK: - Falloff shape

    @Test func `attraction falloff decays to zero at the influence radius`() async throws {
        let influenceRadius = 10.0
        let maxMovement = 1.0

        let justInside = try await displacement(
            atDistance: 9.9, influenceRadius: influenceRadius, maxMovement: maxMovement
        )
        let justOutside = try await displacement(
            atDistance: 10.1, influenceRadius: influenceRadius, maxMovement: maxMovement
        )

        // Outside the influence radius nothing moves, by definition.
        #expect(abs(justOutside) < 1e-9)
        // Just inside it, the falloff has decayed to nothing, so the deformation is continuous
        // across the boundary rather than jumping by the full movement.
        #expect(justInside < maxMovement * 0.01)
        #expect(abs(justInside - justOutside) < maxMovement * 0.01)
    }

    @Test func `attraction is strongest near the target and weakest near the boundary`() async throws {
        let influenceRadius = 10.0
        let maxMovement = 1.0
        let distances = [1.0, 2.0, 4.0, 6.0, 8.0, 9.0, 9.9]

        var displacements: [Double] = []
        for distance in distances {
            displacements.append(try await displacement(
                atDistance: distance, influenceRadius: influenceRadius, maxMovement: maxMovement
            ))
        }

        // A point near the target has to move more than a point near the influence boundary.
        #expect(try #require(displacements.first) > #require(displacements.last))
        // And the strength has to fall off monotonically in between.
        for (nearer, farther) in zip(displacements, displacements.dropFirst()) {
            #expect(nearer > farther)
        }
    }

    @Test func `attraction without a falloff pulls at full strength inside the radius`() async throws {
        let influenceRadius = 10.0

        #expect(try await displacement(
            atDistance: 4, influenceRadius: influenceRadius, maxMovement: 1, falloff: nil
        ) ≈ 1)
        #expect(try await displacement(
            atDistance: 9.9, influenceRadius: influenceRadius, maxMovement: 1, falloff: nil
        ) ≈ 1)
        #expect(try await abs(displacement(
            atDistance: 10.1, influenceRadius: influenceRadius, maxMovement: 1, falloff: nil
        )) < 1e-9)
    }

    // MARK: - Pulling is a plain fixed-distance move

    @Test func `pulling moves every point by the full distance`() async throws {
        // `pulled` uses an unlimited influence radius and no falloff, so the falloff shape must not
        // affect it at all: every point moves by exactly `distance`, however far away it starts.
        let unlimited = Double.greatestFiniteMagnitude

        #expect(try await displacement(
            atDistance: 5, influenceRadius: unlimited, maxMovement: 2, falloff: .none
        ) ≈ 2)
        #expect(try await displacement(
            atDistance: 50, influenceRadius: unlimited, maxMovement: 2, falloff: .none
        ) ≈ 2)
        #expect(try await displacement(
            atDistance: 5000, influenceRadius: unlimited, maxMovement: 2, falloff: .none
        ) ≈ 2)
    }

    @Test func `pulling a box toward the origin keeps its corners where the fixed distance puts them`() async throws {
        let bounds = try #require(try await Box(10).pulled(toward: .zero, distance: 2).bounds)

        // The far corner sits 10·√3 from the origin and slides 2 along that diagonal.
        let farCorner = 10 * (1 - 2 / Vector3D(10, 10, 10).magnitude)
        #expect(bounds.minimum ≈ .zero)
        #expect(bounds.maximum ≈ Vector3D(farCorner, farCorner, farCorner))
    }
}
