import Foundation
import Testing
@testable import Cadova

private func lShape() -> any Geometry2D {
    // Concave (reflex) corner at (5, 5); area 75
    Polygon([[0, 0], [10, 0], [10, 5], [5, 5], [5, 10], [0, 10]])
}

struct EdgeShapingTests {

    @Test func `chamfering vertical box edges removes triangular prisms`() async throws {
        let result = Box(10).shapingEdges(.chamfer(depth: 1), matching: .along(.z))

        // Each of the 4 edges loses a 45° right triangle (area 0.5) along its 10 mm length
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(1000 - 4 * 0.5 * 10, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `chamfering by width removes the equivalent depth-based volume`() async throws {
        // At the box's 90° edges, width = depth·√2, so width √2 matches depth 1
        let result = Box(10).shapingEdges(.chamfer(width: 2.0.squareRoot()), matching: .along(.z))

        let measurements = try await result.measurements
        #expect(measurements.volume.equals(1000 - 4 * 0.5 * 10, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `filleting vertical box edges removes rounded corners`() async throws {
        let radius = 2.0
        let result = Box(10).shapingEdges(.fillet(radius: radius), matching: .along(.z))

        // Each edge loses (r² − πr²/4) per unit length
        let expected = 1000.0 - 4 * (radius * radius - .pi * radius * radius / 4) * 10
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.5))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `filleting by depth matches the equivalent radius on vertical box edges`() async throws {
        let radius = 2.0
        // At 90°, depth = radius·(√2 − 1) produces the same arc as fillet(radius:)
        let result = Box(10).shapingEdges(.fillet(depth: radius * (2.0.squareRoot() - 1)), matching: .along(.z))

        let expected = 1000.0 - 4 * (radius * radius - .pi * radius * radius / 4) * 10
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.5))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `concave edges are filled with material`() async throws {
        let radius = 1.0
        let result = lShape().extruded(height: 10)
            .shapingEdges(.fillet(radius: radius), matching: .concave)

        // The inside corner gains a cove: (r² − πr²/4) per unit length
        let expected = 750.0 + (radius * radius - .pi * radius * radius / 4) * 10
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.1))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `mixed convex and concave edges are shaped in one pass`() async throws {
        let result = lShape().extruded(height: 10)
            .shapingEdges(.chamfer(depth: 1), matching: .along(.z))

        // 5 convex vertical edges are cut (−0.5·10 each), 1 concave is filled (+0.5·10)
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(750 - 5 * 5 + 5, within: 0.1))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `closed edge loops are shaped without seams`() async throws {
        let radius = 5.0
        let depth = 1.0
        let cylinder = Cylinder(radius: radius, height: 10)
        let result = cylinder.shapingEdges(.chamfer(depth: depth), matching: .all)

        let baseVolume = try await cylinder.measurements.volume
        // Each rim loses a toroidal ring; by Pappus, V ≈ 2π·centroidRadius·area
        let ringCut = 2 * .pi * (radius - depth / 3) * (depth * depth / 2)
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(baseVolume - 2 * ringCut, within: baseVolume * 0.01))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `all box edges can be chamfered with flush corners`() async throws {
        let result = Box(10).shapingEdges(.chamfer(depth: 1), matching: .all)

        // Removal per corner (by inclusion–exclusion over the three meeting cuts, whose union
        // includes the flat corner facet): 12 prisms of 5 − 8·(3·⅓ − ¼) = 54
        let expected: Double = 1000 - 54
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `edge shaping works on rotated geometry`() async throws {
        let result = Box(10)
            .rotated(x: 30°, y: 20°, z: 10°)
            .shapingEdges(.chamfer(depth: 1), matching: .all)

        // Same as the axis-aligned all-edges chamfer
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(946, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `custom edge shapes are applied`() async throws {
        // A custom shape equivalent to a chamfer
        let shape = EdgeShape.custom(name: "flat", parameters: 1.0) { parameters in
            let halfAngle = parameters.wedgeAngle / 2
            return [
                Vector2D(cos(halfAngle), sin(halfAngle)),
                Vector2D(cos(halfAngle), -sin(halfAngle)),
            ]
        }
        let result = Box(10).shapingEdges(shape, matching: .along(.z))

        let measurements = try await result.measurements
        #expect(measurements.volume.equals(980, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `shaping explicitly provided edges`() async throws {
        let result = Box(10).readingEdges(matching: .along(.z)) { geometry, edges in
            geometry.shapingEdges(.chamfer(depth: 1), in: edges.filter { edge in
                edge.vertices.allSatisfy { $0.x < 5 }
            })
        }

        // Only the two vertical edges at x == 0 qualify
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(1000 - 2 * 0.5 * 10, within: 0.05))
    }

    @Test func `filleting all box edges produces a rounded box`() async throws {
        let radius = 2.0
        let result = Box(10).shapingEdges(.fillet(radius: radius), matching: .all)

        // Core + face slabs + 12 quarter cylinders + 8 sphere octants
        let core = 6.0 * 6 * 6
        let slabs = 6.0 * 6 * 6 * radius
        let quarterCylinders = 12 * (.pi * radius * radius / 4) * 6
        let sphereOctants = 4.0 / 3 * .pi * radius * radius * radius
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(core + slabs + quarterCylinders + sphereOctants, within: 1.0))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `filleting all box edges by depth produces an exact rounded box corner`() async throws {
        // All three edges at a box corner share the same 90° wedge angle, so the depth-based
        // fillet's per-angle equivalent radius is exact there too — this exercises the
        // corner-patch sphere continuation for a depth-based (not just fixed-radius) fillet.
        let radius = 2.0
        let result = Box(10).shapingEdges(.fillet(depth: radius * (2.0.squareRoot() - 1)), matching: .all)

        let core = 6.0 * 6 * 6
        let slabs = 6.0 * 6 * 6 * radius
        let quarterCylinders = 12 * (.pi * radius * radius / 4) * 6
        let sphereOctants = 4.0 / 3 * .pi * radius * radius * radius
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(core + slabs + quarterCylinders + sphereOctants, within: 1.0))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `chains continuing through a shared corner are merged`() async throws {
        // The top ring: at each corner, exactly two selected edges meet and merge into one loop
        let result = Box(10).shapingEdges(.chamfer(depth: 1), matching: .within(.z, 9.9...))

        // A mitered sweep around a closed path removes area × centroid-path length:
        // the cut triangle's centroid is inset 1/3 from each side face
        let expected = 1000.0 - 0.5 * 4 * (10 - 2.0 / 3)
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `corners with partial edge selection are patched correctly`() async throws {
        // All edges except the bottom ring: top corners join three cuts, bottom ends stay flush
        let result = Box(10).readingEdges(matching: .all) { geometry, edges in
            geometry.shapingEdges(.chamfer(depth: 1), in: edges.filter { $0.boundingBox.maximum.z > 1 })
        }

        // 8 prisms of 5, minus the top-corner overlaps: 4 corners × (3·⅓ − ¼)
        let expected: Double = 1000 - (8 * 5 - 4 * 0.75)
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `concave corners are patched with a spherical cove`() async throws {
        let radius = 2.0
        // A box with a corner pocket: three concave edges meet at the inner corner
        let body = Box(20).subtracting { Box(10) }
        let result = body.shapingEdges(.fillet(radius: radius), matching: .concave)

        // Each cove runs from the inner corner (retracted by r) to the pocket mouth,
        // and the corner itself gains a spherical cove patch
        let coveArea = radius * radius - Double.pi * radius * radius / 4
        let coves = 3 * coveArea * (10 - radius)
        let cornerFill = pow(radius, 3) - Double.pi * pow(radius, 3) / 6
        let expected = 7000 + coves + cornerFill
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(expected, within: 1.0))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `mask shape restricts which edges are shaped`() async throws {
        // A cylinder around the (0,0) vertical edge only
        let result = Box(10).shapingEdges(.chamfer(depth: 1), matching: .along(.z).within {
            Cylinder(radius: 2, height: 30).translated(z: -10)
        })

        let measurements = try await result.measurements
        #expect(measurements.volume.equals(1000 - 0.5 * 10, within: 0.05))

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `mask shape identity is part of the cache key`() async throws {
        let context = _EvaluationContext()
        let query = EdgeQuery.along(.z)

        let maskedNear = Box(10).shapingEdges(
            .chamfer(depth: 1),
            matching: query.within { Cylinder(radius: 2, height: 30).translated(z: -10) }
        )
        _ = try await context.concrete(for: maskedNear)
        let entryCount = await context.cache3D.count

        // A differently-placed mask must not hit the same cache entry despite an
        // otherwise-identical query, shape, and segmentation.
        let maskedFar = Box(10).shapingEdges(
            .chamfer(depth: 1),
            matching: query.within { Cylinder(radius: 2, height: 30).translated(x: 10, y: 10, z: -10) }
        )
        let farResult = try await context.concrete(for: maskedFar)
        let changedCount = await context.cache3D.count
        #expect(changedCount > entryCount)

        let nearVolume = try await context.concrete(for: maskedNear).volume
        #expect(farResult.volume.equals(nearVolume, within: 0.05))
    }

    @Test func `mask can reference a tag defined inside the shaped body`() async throws {
        let target = Tag()
        let body = Box(x: 20, y: 20, z: 20)
            .aligned(at: .center)
            .subtracting {
                Cylinder(diameter: 10, height: 40)
                    .aligned(at: .centerZ)
                    .tagged(target)
            }

        let unshaped = try await body.measurements.volume
        let result = body.shapingEdges(.fillet(depth: 1), matching: .convex.within {
            target.scaled(1.1)
        })

        // The mask must resolve to the (non-empty) tagged cylinder, not an empty placeholder —
        // otherwise the mask admits nothing and the volume is unchanged.
        let measurements = try await result.measurements
        #expect(measurements.volume < unshaped)

        let partCount = try await result.partCount
        #expect(partCount == 1)
    }

    @Test func `edge shaping results are cached`() async throws {
        let context = _EvaluationContext()
        let shaped = Box(10).shapingEdges(.chamfer(depth: 1), matching: .along(.z))

        _ = try await context.concrete(for: shaped)
        let entryCount = await context.cache3D.count

        _ = try await context.concrete(for: shaped)
        let repeatCount = await context.cache3D.count
        #expect(repeatCount == entryCount)

        // Segmentation affects fillet sampling and is part of the cache key
        _ = try await context.concrete(for: shaped, in: .defaultEnvironment.withSegmentation(.fixed(16)))
        let changedCount = await context.cache3D.count
        #expect(changedCount > entryCount)
    }

    @Test func `edge shaping matches golden records`() async throws {
        try await Box(10).shapingEdges(.chamfer(depth: 1), matching: .along(.z))
            .expectEquals(goldenFile: "edge-shaping/box-chamfer-z")
        try await Box(10).shapingEdges(.fillet(radius: 2), matching: .all)
            .expectEquals(goldenFile: "edge-shaping/rounded-box")
        try await lShape().extruded(height: 10).shapingEdges(.fillet(radius: 1), matching: .along(.z))
            .expectEquals(goldenFile: "edge-shaping/l-bracket-mixed")
    }

    @Test func `filleting across a surface crease covers both face orientations`() async throws {
        // A plate whose top breaks from flat into a 25° ramp (the crease is too shallow to be
        // a sharp edge), with a wall crossing the crease obliquely. The faces twist under the
        // fillet at the crossings; the sweep's joint ring there must envelop both adjacent
        // sections — an averaged miter matches neither face, leaving an exposed flank and an
        // unfilled sliver of the corner.
        let plate = Polygon([[0, 0], [40, 0], [40, 3 + 20 * tan(25°)], [20, 3], [0, 3]])
            .extruded(height: 30)
            .rotated(x: 90°)
            .translated(y: 30)
        let body = plate.adding {
            Box(x: 24, y: 4, z: 14)
                .aligned(at: .centerXY)
                .rotated(z: 45°)
                .translated(x: 20, y: 15)
        }
        let result = body.shapingEdges(.fillet(radius: 1), matching: .concave)

        let partCount = try await result.partCount
        #expect(partCount == 1)
        try await result.expectEquals(goldenFile: "edge-shaping/crease-crossing")
    }

    @Test func `shaping with no matching edges returns the body unchanged`() async throws {
        let result = Sphere(radius: 5).shapingEdges(.chamfer(depth: 1), matching: .all)
        let sphereVolume = try await Sphere(radius: 5).measurements.volume
        let measurements = try await result.measurements
        #expect(measurements.volume.equals(sphereVolume, within: 1e-6))
    }

}
