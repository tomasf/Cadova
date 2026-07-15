import Foundation
import Testing
@testable import Cadova

/// Thread-safe container for capturing edges from readingEdges closures in tests.
private final class EdgeCapture: @unchecked Sendable {
    var edges: [FoundEdge] = []
}

private extension Geometry3D {
    func foundEdges(matching query: EdgeQuery = .all) async throws -> [FoundEdge] {
        let capture = EdgeCapture()
        _ = try await readingEdges(matching: query) { geometry, edges in
            capture.edges = edges
            return geometry
        }.node
        return capture.edges
    }
}

private func lShape() -> any Geometry2D {
    // Concave (reflex) corner at (5, 5)
    Polygon([[0, 0], [10, 0], [10, 5], [5, 5], [5, 10], [0, 10]])
}

struct EdgeFindingTests {

    // MARK: - Extraction

    @Test func `box has 12 sharp edges with correct properties`() async throws {
        let edges = try await Box(10).foundEdges()
        #expect(edges.count == 12)

        for edge in edges {
            #expect(edge.length.equals(10, within: 1e-6))
            #expect(edge.averageDihedralAngle.equals(90°, within: 1e-6))
            #expect(edge.isConvex)
            #expect(!edge.isClosed)
            #expect(edge.segments.count == 1)
            #expect(edge.vertices.count == 2)
        }
    }

    @Test func `cylinder has two closed convex rim edges`() async throws {
        let radius = 5.0
        let edges = try await Cylinder(radius: radius, height: 10).foundEdges()
        #expect(edges.count == 2)

        for edge in edges {
            #expect(edge.isClosed)
            #expect(edge.isConvex)
            #expect(edge.averageDihedralAngle.equals(90°, within: 1))
            // The polygonal rim is slightly shorter than the ideal circle
            #expect(edge.length > 2 * .pi * radius * 0.95 && edge.length < 2 * .pi * radius * 1.01)
            #expect(edge.vertices.count == edge.segments.count)
        }
    }

    @Test func `sphere has no sharp edges`() async throws {
        let edges = try await Sphere(radius: 5).foundEdges()
        #expect(edges.isEmpty)
    }

    @Test func `edge segments carry correct face normals`() async throws {
        let edges = try await Box(10).foundEdges(matching: .within(.z, 9.9...).along(.x))

        try #require(edges.count == 2)
        for edge in edges {
            let segment = try #require(edge.segments.first)
            let normals = Set([segment.leftFaceNormal, segment.rightFaceNormal].map {
                Vector3D($0.unitVector.x.rounded(), $0.unitVector.y.rounded(), $0.unitVector.z.rounded())
            })
            // Top X-aligned edges border the top face (+Z) and a Y-facing side face
            #expect(normals.contains(Vector3D(0, 0, 1)))
            #expect(normals.count == 2)
        }
    }

    // MARK: - Convexity

    @Test func `l-shaped extrusion has exactly one concave edge`() async throws {
        let edges = try await lShape().extruded(height: 10).foundEdges(matching: .concave)

        try #require(edges.count == 1)
        let edge = edges[0]
        #expect(edge.length.equals(10, within: 1e-6))
        #expect(!edge.isConvex)
        #expect(edge.averageDihedralAngle.equals(270°, within: 1e-6))
        #expect(edge.vertices.allSatisfy { $0.x.equals(5, within: 1e-6) && $0.y.equals(5, within: 1e-6) })
    }

    @Test func `convexity filters partition edges`() async throws {
        let solid = lShape().extruded(height: 10)
        let all = try await solid.foundEdges()
        let convex = try await solid.foundEdges(matching: .convex)
        let concave = try await solid.foundEdges(matching: .concave)

        #expect(convex.count + concave.count == all.count)
        #expect(concave.count == 1)

        let boxConcave = try await Box(10).foundEdges(matching: .concave)
        #expect(boxConcave.isEmpty)
    }

    // MARK: - Directional filters

    @Test func `along z finds the four vertical box edges`() async throws {
        let edges = try await Box(10).foundEdges(matching: .along(.z))
        #expect(edges.count == 4)
        #expect(edges.allSatisfy { abs($0.segments[0].direction.unitVector.z) > 0.99 })
    }

    @Test func `along x finds four box edges`() async throws {
        let edges = try await Box(10).foundEdges(matching: .along(.x))
        #expect(edges.count == 4)
    }

    @Test func `perpendicular to z finds the eight horizontal box edges`() async throws {
        let edges = try await Box(10).foundEdges(matching: .perpendicular(to: .z))
        #expect(edges.count == 8)
    }

    @Test func `along a line selects only edges lying on it`() async throws {
        // Unlike an axis, a line is positioned: only the one vertical edge at the origin lies
        // on the Z axis line
        let onAxis = try await Box(10).foundEdges(matching: .along(line: Line3D(axis: .z)))
        try #require(onAxis.count == 1)
        #expect(onAxis[0].vertices.allSatisfy { $0.x.equals(0, within: 1e-6) && $0.y.equals(0, within: 1e-6) })

        let opposite = try await Box(10).foundEdges(matching: .along(line: Line3D(axis: .z, offset: [10, 10, 0])))
        #expect(opposite.count == 1)

        // A line between edges matches nothing
        let between = try await Box(10).foundEdges(matching: .along(line: Line3D(axis: .z, offset: [5, 0, 0])))
        #expect(between.isEmpty)
    }

    @Test func `along a line works at arbitrary orientations`() async throws {
        let rotation = Transform3D.rotation(x: 30°, y: 20°, z: 10°)
        let solid = Box(10).rotated(x: 30°, y: 20°, z: 10°)

        // The box corner at the origin stays put; follow its former vertical edge
        let line = Line3D(from: .zero, to: rotation.apply(to: Vector3D(0, 0, 10)))
        let edges = try await solid.foundEdges(matching: .along(line: line))
        try #require(edges.count == 1)
        #expect(edges[0].length.equals(10, within: 1e-6))
    }

    @Test func `parallel and perpendicular accept arbitrary directions`() async throws {
        // Rotating a box 45° around X points its former vertical edges along (0, -1, 1)
        let solid = Box(10).rotated(x: 45°)

        let parallel = try await solid.foundEdges(matching: .parallel(to: Direction3D(y: -1, z: 1)))
        #expect(parallel.count == 4)

        // Orientation along the direction doesn't matter
        let opposite = try await solid.foundEdges(matching: .parallel(to: Direction3D(y: 1, z: -1)))
        #expect(opposite.count == 4)

        let perpendicular = try await solid.foundEdges(matching: .perpendicular(to: Direction3D(y: -1, z: 1)))
        #expect(perpendicular.count == 8)
    }

    @Test func `parallel and perpendicular accept lines, ignoring their position`() async throws {
        let solid = Box(10).rotated(x: 45°)
        let line = Line3D(point: [100, 100, 100], direction: Direction3D(y: -1, z: 1))

        let parallel = try await solid.foundEdges(matching: .parallel(to: line))
        #expect(parallel.count == 4)

        let perpendicular = try await solid.foundEdges(matching: .perpendicular(line: line))
        #expect(perpendicular.count == 8)
    }

    // MARK: - Spatial filters

    @Test func `above plane finds the top ring of a box`() async throws {
        let edges = try await Box(10).foundEdges(matching: .above(.z(9.9)))
        #expect(edges.count == 4)
    }

    @Test func `below plane finds the bottom ring of a box`() async throws {
        let edges = try await Box(10).foundEdges(matching: .below(.z(0.1)))
        #expect(edges.count == 4)
    }

    @Test func `within axis ranges select edges in a band`() async throws {
        let edges = try await Box(10).foundEdges(
            matching: .along(.z).within(.x, -0.1...5.0).within(.y, -0.1...5.0)
        )
        #expect(edges.count == 1)
    }

    @Test func `within with per-axis ranges selects edges in a region`() async throws {
        let edges = try await Box(10).foundEdges(
            matching: .along(.z).within(x: -0.1...5.0, y: -0.1...5.0)
        )
        #expect(edges.count == 1)

        let topRing = try await Box(10).foundEdges(matching: .within(z: 9.9...))
        #expect(topRing.count == 4)

        let unbounded = try await Box(10).foundEdges(matching: .within())
        #expect(unbounded.count == 12)
    }

    @Test func `within accepts open-ended ranges`() async throws {
        let edges = try await Box(10).foundEdges(matching: .within(.z, 9.9...))
        #expect(edges.count == 4)
    }

    @Test func `within bounding box selects contained edges`() async throws {
        let box = BoundingBox3D(minimum: [-0.1, -0.1, -0.1], maximum: [10.1, 5.0, 10.1])
        let edges = try await Box(10).foundEdges(matching: .within(box))
        // Edges entirely within y <= 5: the four X/Z-plane edges at y=0
        #expect(edges.count == 4)
    }

    @Test func `on a plane selects edges lying on either side of it`() async throws {
        // The four bottom edges lie exactly on z = 0; above/below would each need a sign
        let edges = try await Box(10).foundEdges(matching: .on(.z(0)))
        #expect(edges.count == 4)

        // A plane through the box's interior, touching no edges
        let none = try await Box(10).foundEdges(matching: .on(.z(5)))
        #expect(none.isEmpty)
    }

    @Test func `near a point selects only edges entirely within radius`() async throws {
        // Only the x-edge from the origin fits entirely within radius 6: its far vertex sits
        // at distance 5, while the y- and z-edges' far vertices sit farther away (8 and 12)
        let solid = Box(x: 5, y: 8, z: 12)

        let edges = try await solid.foundEdges(matching: .near(.zero, within: 6))
        try #require(edges.count == 1)
        #expect(edges[0].length.equals(5, within: 1e-6))

        // A radius smaller than every edge's reach admits nothing
        let none = try await solid.foundEdges(matching: .near(.zero, within: 2))
        #expect(none.isEmpty)
    }

    // MARK: - Length filters

    @Test func `withLength filters edges by their total length`() async throws {
        // A box stretched along Z: the 4 vertical edges are longer than the 8 base/top edges
        let solid = Box(x: 10, y: 10, z: 20)

        let long = try await solid.foundEdges(matching: .withLength(15...))
        #expect(long.count == 4)
        #expect(long.allSatisfy { $0.length.equals(20, within: 1e-6) })

        let short = try await solid.foundEdges(matching: .withLength(...15))
        #expect(short.count == 8)

        let none = try await solid.foundEdges(matching: .withLength(100...))
        #expect(none.isEmpty)
    }

    // MARK: - Topology filters

    @Test func `topology filters distinguish open and closed edges`() async throws {
        let closedBoxEdges = try await Box(10).foundEdges(matching: .closed)
        let openBoxEdges = try await Box(10).foundEdges(matching: .open)
        let closedCylinderEdges = try await Cylinder(radius: 5, height: 10).foundEdges(matching: .closed)
        let openCylinderEdges = try await Cylinder(radius: 5, height: 10).foundEdges(matching: .open)

        #expect(closedBoxEdges.isEmpty)
        #expect(openBoxEdges.count == 12)
        #expect(closedCylinderEdges.count == 2)
        #expect(openCylinderEdges.isEmpty)
    }

    // MARK: - Sharpness

    @Test func `sharpness minimum controls which edges are found`() async throws {
        // A hexagonal prism's side-to-side edges deviate 60° from flat; its rim edges deviate 90°.
        let hexagon = Polygon((0..<6).map { index in
            let angle = Double(index) / 6 * 360°
            return Vector2D(x: 5 * cos(angle), y: 5 * sin(angle))
        })
        let prism = hexagon.extruded(height: 10)

        let defaultEdges = try await prism.foundEdges()
        #expect(defaultEdges.count == 18)  // 6 vertical + two rims of 6 (split at degree-3 corners)

        let steepOnly = try await prism.foundEdges(matching: .withSharpness(70°...))
        // Only the rim edges remain; their 60° corners still split them under the default
        // 45° turn limit, but the excluded verticals no longer make those corners junctions
        #expect(steepOnly.count == 12)
        #expect(steepOnly.allSatisfy { !$0.isClosed })
    }

    @Test func `sharpness single value with tolerance finds a narrow band`() async throws {
        let edges = try await Box(10).foundEdges(matching: .withSharpness(90°))
        #expect(edges.count == 12)

        let none = try await Box(10).foundEdges(matching: .withSharpness(60°))
        #expect(none.isEmpty)

        let wideTolerance = try await Box(10).foundEdges(matching: .withSharpness(95°, tolerance: 10°))
        #expect(wideTolerance.count == 12)
    }

    // MARK: - Sharpness maximum

    @Test func `sharpness maximum excludes overly sharp edges`() async throws {
        // Equilateral triangle prism: dihedral 60° (deviation 120°) — very sharp.
        let triangle = Polygon([[0, 0], [10, 0], [5, 5 * 3.0.squareRoot()]])
        let trianglePrism = triangle.extruded(height: 10)

        let query = EdgeQuery.withSharpness(30°...100°)

        // Restrict to the vertical edges — the top/bottom cap edges (where the walls meet the
        // caps) are 90° dihedral regardless of the base polygon, so they'd pass the band too.
        let triangleEdges = try await trianglePrism.foundEdges(matching: query.along(.z))
        #expect(triangleEdges.isEmpty)  // deviation 120° exceeds the 100° cap

        let boxEdges = try await Box(10).foundEdges(matching: query.along(.z))
        #expect(boxEdges.count == 4)  // deviation 90° is within the band
    }

    @Test func `sharpness band merges chains across excluded angles`() async throws {
        // A hexagonal prism: rim edges dihedral 90° (deviation 90°), vertical edges dihedral
        // 120° (deviation 60°). The default minimum extracts both, splitting each rim into
        // 6 segments at the degree-3 junctions with the vertical edges.
        let hexagon = Polygon((0..<6).map { index in
            let angle = Double(index) / 6 * 360°
            return Vector2D(x: 5 * cos(angle), y: 5 * sin(angle))
        })
        let prism = hexagon.extruded(height: 10)

        let defaultEdges = try await prism.foundEdges()
        #expect(defaultEdges.count == 18)

        // Raising the minimum to 80° excludes the 60°-deviation vertical edges from extraction
        // entirely — they're invisible to chain-building, so the rim corners are no longer
        // junctions. Allowing turns of up to 90° then merges each rim into one closed loop.
        let mergedRims = try await prism.foundEdges(matching: .withSharpness(80°...100°).withMaxTurn(90°))
        #expect(mergedRims.count == 2)
        #expect(mergedRims.allSatisfy { $0.isClosed })
    }

    // MARK: - Turn limit

    @Test func `turn limit controls how far an edge continues through corners`() async throws {
        // A hexagonal prism rim with band-excluded verticals: each rim corner is a degree-2
        // vertex turning 60°. The default 45° limit splits there; raising it merges.
        let hexagon = Polygon((0..<6).map { index in
            let angle = Double(index) / 6 * 360°
            return Vector2D(x: 5 * cos(angle), y: 5 * sin(angle))
        })
        let prism = hexagon.extruded(height: 10)
        let rimsOnly = EdgeQuery.withSharpness(80°...100°)

        let split = try await prism.foundEdges(matching: rimsOnly)
        #expect(split.count == 12)
        #expect(split.allSatisfy { !$0.isClosed && $0.segments.count == 1 })

        let merged = try await prism.foundEdges(matching: rimsOnly.withMaxTurn(70°))
        #expect(merged.count == 2)
        #expect(merged.allSatisfy { $0.isClosed && $0.segments.count == 6 })

        // A cylinder's finely segmented rims turn only a few degrees per vertex, so they
        // survive even a much tighter limit than the default
        let rims = try await Cylinder(radius: 5, height: 10).foundEdges(matching: .withMaxTurn(10°))
        #expect(rims.count == 2)
        #expect(rims.allSatisfy { $0.isClosed })
    }

    @Test func `sharpness maximum combines with other constraints`() async throws {
        let edges = try await Box(10).foundEdges(matching: .withSharpness(80°...100°).along(.z))
        #expect(edges.count == 4)
    }

    // MARK: - Mask filters

    @Test func `mask filters edges by an arbitrary shape`() async throws {
        // A cylinder around the (0,0) vertical edge only, not axis-aligned so within(_:) alone
        // couldn't express this.
        let edges = try await Box(10).foundEdges(matching: .along(.z).within {
            Cylinder(radius: 2, height: 30).translated(z: -10)
        })

        try #require(edges.count == 1)
        #expect(edges[0].vertices.allSatisfy { $0.x.equals(0, within: 1e-6) && $0.y.equals(0, within: 1e-6) })
    }

    @Test func `mask excludes edges entirely outside it`() async throws {
        let edges = try await Box(10).foundEdges(matching: .within {
            Sphere(radius: 1).translated(x: 100, y: 100, z: 100)
        })
        #expect(edges.isEmpty)
    }

    @Test func `mask combines with other constraints`() async throws {
        // A thin slab along y=0 admits both the (0,0) and (10,0) vertical edges;
        // .within(x: ...1) narrows that down to just the one at (0,0).
        let edges = try await Box(10).foundEdges(matching: .along(.z).within {
            Box(x: 12, y: 2, z: 30).translated(x: -1, y: -1, z: -10)
        }.within(x: ...1))

        try #require(edges.count == 1)
        #expect(edges[0].vertices.allSatisfy { $0.x.equals(0, within: 1e-6) && $0.y.equals(0, within: 1e-6) })
    }

    @Test func `mask combines multiple shapes via the builder`() async throws {
        // Two separate cylinders, one around each of two opposite vertical edges
        let edges = try await Box(10).foundEdges(matching: .along(.z).within {
            Cylinder(radius: 2, height: 30).translated(z: -10)
            Cylinder(radius: 2, height: 30).translated(x: 10, y: 10, z: -10)
        })

        #expect(edges.count == 2)
    }

    @Test func `mask can reference a tag defined inside the body`() async throws {
        let target = Tag()
        let body = Box(10).subtracting {
            Cylinder(radius: 1, height: 30).translated(x: 5, y: 5, z: -10).tagged(target)
        }

        // If the tag failed to resolve, the mask would be an empty placeholder and admit nothing.
        let edges = try await body.foundEdges(matching: .within { target.scaled(2) })
        #expect(!edges.isEmpty)
    }

    // MARK: - Face continuity

    @Test func `edges continue across a shallow surface crease`() async throws {
        // A plate whose top surface breaks from flat (z=3) into a 25° ramp at x=20 — too
        // shallow for the crease itself to count as a sharp edge — with a wall crossing the
        // crease obliquely. The concave edge at the wall's base runs from the flat floor
        // onto the ramp as one continuous chain; the gentle kink at the crossing is well
        // under the turn limit.
        let body = Polygon([[0, 0], [40, 0], [40, 3 + 20 * tan(25°)], [20, 3], [0, 3]])
            .extruded(height: 30)
            .rotated(x: 90°)
            .translated(y: 30)
            .adding {
                Box(x: 24, y: 4, z: 14)
                    .aligned(at: .centerXY)
                    .rotated(z: 45°)
                    .translated(x: 20, y: 15)
            }

        let edges = try await body.foundEdges(matching: .concave)

        // The wall's base loop splits only at its four corners (junctions with the vertical
        // wall edges); the two long sides each cross the crease mid-chain.
        #expect(edges.count == 4)
        let crossing = edges.count { edge in
            edge.vertices.contains { $0.z.equals(3, within: 1e-6) } && edge.vertices.contains { $0.z > 3.01 }
        }
        #expect(crossing == 2)
    }

    // MARK: - Visualization

    @Test func `visualized edges produce solid geometry in a visual-only part`() async throws {
        let edges = try await Box(10).foundEdges(matching: .along(.z))
        let visualization = Empty().visualizingEdges(edges)

        #expect(try await visualization.partNames == ["Visualized Edges"])
        #expect(try await visualization.measurements(for: .allParts).volume > 0)
    }

    @Test func `visualizingEdges matching a query adds a visual part without affecting solid volume`() async throws {
        let box = try await Box(10).measurements
        let visualization = Box(10).visualizingEdges(matching: .along(.z))

        #expect(try await visualization.partNames.contains("Visualized Edges"))
        #expect(try await visualization.measurements.volume == box.volume)
        #expect(try await visualization.measurements(for: .allParts).volume > box.volume)
    }
}
