import Foundation
import Testing
@testable import Cadova

struct Offset3DTests {
    // Coarser than the default, to keep the tests quick: rounded parts are then accurate to 0.04
    let segmentation = Segmentation.adaptive(minAngle: 2°, minSize: 0.4)

    @Test func `offsetting a box inward shrinks it by the amount on every side, with sharp corners`() async throws {
        let offset = Box(20).offset(amount: -2).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        let volume = try await offset.measurements.volume

        let expectedVolume = 16.0 * 16 * 16
        #expect(bounds ≈ BoundingBox3D(minimum: [2, 2, 2], maximum: [18, 18, 18]))
        #expect(volume.equals(expectedVolume, within: 0.01))
    }

    @Test func `offsetting a box outward rounds its edges and corners with the amount as radius`() async throws {
        let offset = Box(20).offset(amount: 2).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        let volume = try await offset.measurements.volume

        // The box, a slab on each face, a quarter cylinder along each edge and an eighth of a sphere at each corner
        let faces = 6 * 20.0 * 20 * 2
        let edges = 12 * 20 * Double.pi * 2 * 2 / 4
        let corners = 4.0 / 3 * .pi * 2 * 2 * 2
        let expectedVolume = 8000 + faces + edges + corners
        // Rounded parts are accurate to a tenth of the segmentation's minimum size
        #expect(bounds.minimum.x.equals(-2, within: 0.04) && bounds.maximum.z.equals(22, within: 0.04))
        #expect(volume.equals(expectedVolume, within: expectedVolume * 0.002))
    }

    @Test func `offsetting inward rounds concave corners with the amount as radius`() async throws {
        // An L-shaped plate: the concave inner corner is where the rounding appears
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let volume = try await plate.offset(amount: -2).withSegmentation(segmentation).measurements.volume

        // Offsetting by 2 shrinks the L to 26 × 26 minus a 15 × 15 notch, and its height from 10 to 6. A sharp
        // concave corner would give exactly that; rounding keeps the 2 × 2 corner square minus a quarter disc
        let sharpArea = 26.0 * 26 - 15 * 15
        let expectedVolume = (sharpArea + 4 - Double.pi) * 6
        #expect(volume.equals(expectedVolume, within: expectedVolume * 0.001))
    }

    @Test func `offsetting a sphere changes its radius`() async throws {
        let offset = Sphere(radius: 10).offset(amount: 3).withSegmentation(segmentation)
        let bounds = try #require(try await offset.bounds)
        #expect(bounds.size.x.equals(26, within: 0.1))
        #expect(bounds.size.z.equals(26, within: 0.1))
    }

    @Test func `parts thinner than twice the amount disappear when offsetting inward`() async throws {
        let plate = Box([20, 20, 3]).offset(amount: -2).withSegmentation(segmentation)
        #expect(try await plate.measurements.volume == 0)

        // A thin fin on a thick base: the fin goes, and only bulges the base's offset top up a little, where the
        // corners at the fin's foot are the closest surface: √(0.5² + h²) = 2 at its center line
        let finned = Box([20, 20, 10])
            .adding { Box([1, 20, 10]).translated(x: 10, z: 10) }
            .offset(amount: -2)
            .withSegmentation(segmentation)
        let bounds = try #require(try await finned.bounds)
        #expect(bounds.maximum.z.equals(10 - (4 - 0.25).squareRoot(), within: 0.04))
    }

    @Test func `a zero offset leaves the geometry unchanged`() async throws {
        let volume = try await Box(10).offset(amount: 0).measurements.volume
        #expect(volume.equals(1000, within: 1e-9))
    }

    @Test func `hollowing leaves walls of the given thickness`() async throws {
        let volume = try await Box(20).hollowed(wallThickness: 2).withSegmentation(segmentation).measurements.volume
        let expectedVolume = 20.0 * 20 * 20 - 16 * 16 * 16
        #expect(volume.equals(expectedVolume, within: 0.01))
    }

    @Test func `offsetting with a reader provides the original and the offset`() async throws {
        // Everything within 2 of the surface: the box minus its inward offset
        let shell = Box(10).offset(amount: -2) { original, offset in
            original.subtracting { offset }
        }
        let volume = try await shell.withSegmentation(segmentation).measurements.volume
        #expect(volume.equals(1000 - 6 * 6 * 6, within: 0.01))
    }

    @Test func `hollowing shapes the cavity across from inside corners by the style`() async throws {
        // An L-shaped block has one inside corner, a vertical concave edge. Along it, the cavity is shrunk by the
        // walls around the corner: by a 2 × 2 square with the miter style, a quarter disc of radius 2 with round,
        // and a triangle with legs of 2 with bevel, along its 16 of height. The more it's shrunk, the more wall.
        let block = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 20)
        func volume(_ style: LineJoinStyle) async throws -> Double {
            try await block.hollowed(wallThickness: 2, style: style).withSegmentation(segmentation).measurements.volume
        }
        let round = try await volume(.round), miter = try await volume(.miter), bevel = try await volume(.bevel)
        #expect((miter - round).equals(16 * (4 - Double.pi), within: 0.5))
        #expect((miter - bevel).equals(16 * 2, within: 0.5))
    }

    @Test func `hollowing keeps parts thinner than two walls solid`() async throws {
        let volume = try await Box([20, 20, 3]).hollowed(wallThickness: 2).measurements.volume
        #expect(volume.equals(1200, within: 1e-6))
    }

    // Join styles: flat faces and sharp edges are exact at any resolution, so these expectations are exact

    @Test func `mitered offsets keep edges and corners sharp`() async throws {
        let cube = try await Box(20).offset(amount: 2, style: .miter).withSegmentation(segmentation).measurements.volume
        let shrunk = try await Box(20).offset(amount: -2, style: .miter).withSegmentation(segmentation).measurements.volume
        #expect(cube.equals(24 * 24 * 24, within: 0.01))
        #expect(shrunk.equals(16 * 16 * 16, within: 0.01))

        // The L's concave inner corner stays sharp when shrinking, unlike with round
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let grownPlate = try await plate.offset(amount: 2, style: .miter).withSegmentation(segmentation).measurements.volume
        let shrunkPlate = try await plate.offset(amount: -2, style: .miter).withSegmentation(segmentation).measurements.volume
        let grownArea = 34.0 * 34 - 15 * 15
        let shrunkArea = 26.0 * 26 - 15 * 15
        #expect(grownPlate.equals(grownArea * 14, within: 0.01))
        #expect(shrunkPlate.equals(shrunkArea * 6, within: 0.01))
    }

    @Test func `beveled offsets cut edges and corners flat between the moved faces`() async throws {
        // The box, a slab on each face, a triangular prism along each edge and a corner tetrahedron at each corner
        let volume = try await Box(20).offset(amount: 2, style: .bevel).withSegmentation(segmentation).measurements.volume
        let faces = 6 * 20.0 * 20 * 2
        let edges = 12 * 20 * 2.0 * 2 / 2
        let corners = 8 * 2.0 * 2 * 2 / 6
        let expected = 8000 + faces + edges + corners
        #expect(volume.equals(expected, within: 0.01))

        // Shrinking the L keeps a 2 × 2 triangle at its concave inner corner
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let shrunkPlate = try await plate.offset(amount: -2, style: .bevel).withSegmentation(segmentation).measurements.volume
        let shrunkArea = 26.0 * 26 - 15 * 15 + 2
        #expect(shrunkPlate.equals(shrunkArea * 6, within: 0.01))
    }

    @Test func `squared offsets cut edges and corners flat at the amount`() async throws {
        // Each edge is cut 2 from the edge along its bisector, and each corner 2 from the corner along its diagonal and
        // by the cuts of its edges. The corner volume is the region of the 2 × 2 × 2 corner cube within all four cuts.
        let volume = try await Box(20).offset(amount: 2, style: .square).withSegmentation(segmentation).measurements.volume
        let edgeArea = 4 * (2 * 2.0.squareRoot() - 2)
        let corner = 4.776610891
        let expected = 8000 + 6 * 20.0 * 20 * 2 + 12 * 20 * edgeArea + 8 * corner
        #expect(volume.equals(expected, within: 0.01))

        // Shrinking the L keeps the 2 × 2 corner square minus the square join's share of it
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let shrunkPlate = try await plate.offset(amount: -2, style: .square).withSegmentation(segmentation).measurements.volume
        let shrunkArea = 26.0 * 26 - 15 * 15 + 4 - edgeArea
        #expect(shrunkPlate.equals(shrunkArea * 6, within: 0.01))
    }

    @Test func `a miter reaching past the miter limit is squared off`() async throws {
        // A prism with a 30° edge pointing along -x: a miter reaches 2 / sin(15°) ≈ 7.73 past it
        let halfWidth = 40 * tan(15° as Angle)
        let wedge = Polygon([[0, 0], [40, halfWidth], [40, -halfWidth]])
            .extruded(height: 10)
        let mitered = try #require(try await wedge.offset(amount: 2, style: .miter).withSegmentation(segmentation).bounds)
        let squared = try #require(try await wedge.offset(amount: 2, style: .miter).withMiterLimit(2).withSegmentation(segmentation).bounds)
        #expect(mitered.minimum.x.equals(-2 / sin(15° as Angle), within: 0.01))
        #expect(squared.minimum.x.equals(-2, within: 0.01))
    }

    @Test func `curved surfaces stay smooth with sharp join styles`() async throws {
        let round = try #require(try await Sphere(radius: 10).offset(amount: 3).withSegmentation(segmentation).bounds)
        let mitered = try #require(try await Sphere(radius: 10).offset(amount: 3, style: .miter).withSegmentation(segmentation).bounds)
        #expect(mitered.size.x.equals(round.size.x, within: 0.05))
    }

    // Rounding and chamfering: two offsets each

    @Test func `rounding the outside of a box rounds its edges and corners`() async throws {
        let volume = try await Box(20).rounded(outsideRadius: 2).withSegmentation(segmentation).measurements.volume
        // The box shrunk by 2, a slab on each face, a quarter cylinder along each edge and an eighth of a sphere at
        // each corner
        let faces = 16.0 * 16 * 16 + 6 * 16 * 16 * 2
        let edges = 12 * 16 * Double.pi * 2 * 2 / 4
        let corners = 4.0 / 3 * .pi * 2 * 2 * 2
        let expected = faces + edges + corners
        #expect(volume.equals(expected, within: expected * 0.002))
    }

    @Test func `rounding the inside fillets concave edges and leaves convex ones sharp`() async throws {
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let rounded = plate.rounded(insideRadius: 2).withSegmentation(segmentation)
        let volume = try await rounded.measurements.volume
        let bounds = try #require(try await rounded.bounds)
        // The concave inner edge gains a 2 × 2 square less a quarter disc along its height; everything else stays
        let area: Double = 30 * 30 - 15 * 15 + 4 - Double.pi
        let expected = area * 10
        #expect(volume.equals(expected, within: expected * 0.001))
        #expect(bounds ≈ BoundingBox3D(minimum: [0, 0, 0], maximum: [30, 30, 10]))
    }

    @Test func `rounding both sides rounds convex edges and fillets concave ones`() async throws {
        // A box has no concave edges: rounding both sides is rounding the outside
        let box = try await Box(20).rounded(radius: 2).withSegmentation(segmentation).measurements.volume
        let faces = 16.0 * 16 * 16 + 6 * 16 * 16 * 2
        let edges = 12 * 16 * Double.pi * 2 * 2 / 4
        let corners = 4.0 / 3 * .pi * 2 * 2 * 2
        let expectedBox = faces + edges + corners
        #expect(box.equals(expectedBox, within: expectedBox * 0.002))

        // The L-plate gains the concave fillet that inside rounding alone adds, minus what outside rounding alone
        // removes: the two act on different edges
        let plate = Rectangle(x: 30, y: 30)
            .subtracting { Rectangle(x: 15, y: 15).translated(x: 15, y: 15) }
            .extruded(height: 10)
        let both = try await plate.rounded(radius: 2).withSegmentation(segmentation).measurements.volume
        let outside = try await plate.rounded(outsideRadius: 2).withSegmentation(segmentation).measurements.volume
        let inside = try await plate.rounded(insideRadius: 2).withSegmentation(segmentation).measurements.volume
        let original = (30.0 * 30 - 15 * 15) * 10
        let expected = original + (inside - original) - (original - outside)
        #expect(both.equals(expected, within: expected * 0.002))
    }

    @Test func `rounding both sides keeps fillets smooth`() async throws {
        // Rounding the inside after the outside used to contour the outside's fillets again, which merged their
        // facets into coarse creases of up to 38° at this resolution; one contouring keeps them as a single offset
        // makes them, under 30°
        let rounded = Box(10).rounded(radius: 0.5).withSegmentation(.adaptive(minAngle: 2°, minSize: 0.15))
        let mesh = try await _EvaluationContext().concrete(for: rounded, in: .defaultEnvironment).meshGL()
        #expect(Self.largestCrease(vertices: mesh.vertices, triangles: mesh.triangles.map { ($0.a, $0.b, $0.c) }) < 30)
    }

    /// The largest angle in degrees between the normals of triangles sharing an edge
    private static func largestCrease(vertices: [Vector3D], triangles: [(Int, Int, Int)]) -> Double {
        var normals: [Vector3D] = []
        var facesOfEdge: [UInt64: [Int]] = [:]
        for (index, triangle) in triangles.enumerated() {
            let a = vertices[triangle.0], b = vertices[triangle.1], c = vertices[triangle.2]
            normals.append(((b - a) × (c - a)).normalized)
            for (u, v) in [(triangle.0, triangle.1), (triangle.1, triangle.2), (triangle.2, triangle.0)] {
                facesOfEdge[UInt64(min(u, v)) << 32 | UInt64(max(u, v)), default: []].append(index)
            }
        }
        return facesOfEdge.values.filter { $0.count == 2 }.map { pair in
            acos(min(max(normals[pair[0]] ⋅ normals[pair[1]], -1), 1)) * 180 / .pi
        }.max() ?? 0
    }

    @Test func `chamfering the outside of a box cuts its edges and corners flat`() async throws {
        let volume = try await Box(20).chamfered(outsideDepth: 2).withSegmentation(segmentation).measurements.volume
        // The box shrunk by 2 and offset back out by 2 with square joins, as in the squared offset test
        let edgeArea = 4 * (2 * 2.0.squareRoot() - 2)
        let corner = 4.776610891
        let faces = 16.0 * 16 * 16 + 6 * 16 * 16 * 2
        let expected = faces + 12 * 16 * edgeArea + 8 * corner
        #expect(volume.equals(expected, within: 0.01))
    }

    @Test func `beveling past a thin wall stays within the original`() async throws {
        // Walls thinner than twice the amount disappear. Bevels at the pocket's inner edges used to reach through
        // them to the far side, leaving material outside the original there.
        let pocket = Box([20, 20, 10])
            .subtracting { Box([20 - 2.7, 20 - 2.7, 10]).translated(x: 1.35, y: 1.35, z: 4) }
            .withSegmentation(.adaptive(minAngle: 2°, minSize: 0.3))
        let shrunk = pocket.offset(amount: -1, style: .bevel)
        let outside = try await shrunk.subtracting { pocket }.measurements.volume
        #expect(outside < 1e-6)
    }

    @Test func `offsetting the result of earlier offsets stays manifold`() async throws {
        // Offsets of offsets can come with folded triangles, which made pseudonormals point the wrong way and left
        // holes in the next offset
        let shape = Box(x: 20, y: 30, z: 15)
            .aligned(at: .centerXY)
            .adding {
                Text("Te")
                    .withTextAlignment(horizontal: .center, vertical: .center)
                    .extruded(height: 2)
                    .translated(z: 15)
                    .rotated(z: 90°)
                    .offset(amount: 0.7, style: .miter)
            }
            .rounded(radius: 0.5)
            .withSegmentation(.adaptive(minAngle: 2°, minSize: 0.25))
        let volume = try await shape.measurements.volume
        #expect(volume > 9000)
    }

    @Test func `closest points on triangles with coinciding corners are finite`() {
        // The first triangle has two corners in one place, so one of its edges has no length. Starting the search
        // from it, as a hint does, used to give a distance of NaN that no other face could beat
        let field = MeshDistanceField(
            vertices: [[0, 0, 0], [0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
            faces: [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 2), (2, 4, 3)]
        )
        for point: Vector3D in [[0.5, -1, 0], [0.5, 1, 0], [-1, -1, -1], [0.3, 0.3, 0.3]] {
            let closest = field.closest(to: point, hint: 0)
            #expect(closest.distanceSquared.isFinite)
        }
    }

    @Test func `holes in contoured meshes are closed`() {
        // A cube with its top missing
        let vertices: [Vector3D] = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]]
        let faces: [MeshOffset.Face] = [
            (0, 2, 1), (0, 3, 2), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5),
            (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7),
        ]
        let closed = try? #require(MeshOffset.filledHoles(vertices: vertices, faces: faces))
        guard let closed else { return }
        var uses: [Int: Int] = [:]
        for face in closed.faces {
            for (a, b) in [(face.0, face.1), (face.1, face.2), (face.2, face.0)] {
                uses[a << 32 | b, default: 0] += 1
                uses[b << 32 | a, default: 0] -= 1
            }
        }
        #expect(uses.values.allSatisfy { $0 == 0 })
        #expect(closed.faces.count == faces.count + 4)
        #expect(MeshOffset.filledHoles(vertices: closed.vertices, faces: closed.faces) == nil)
    }

    @Test func `corner cones hold every normal, whatever order the faces come in`() throws {
        // A vertex's normals in ring order can fold back on crumpled geometry; the cone is still their hull
        let normals = ([[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [0.2, 0.1, 1]] as [Vector3D]).map(\.normalized)
        let axis = normals.reduce(Vector3D.zero, +).normalized
        let sides = try #require(OffsetCorners.coneSides(of: normals, around: axis))
        #expect(sides.count == 4)
        for side in sides {
            #expect(normals.allSatisfy { $0 ⋅ side >= -1e-9 })
        }
        // Normals nearly on one great circle, from a real model, span too thin a cone to tell which way its sides
        // face; getting that wrong let a corner reach far past the miter limit
        let thin: [Vector3D] = [[0.452496, 0.23139, -0.861224], [0.64953, -0.320693, -0.689396], [-0.483882, 0.874923, -0.0191661]]
        #expect(OffsetCorners.coneSides(of: thin, around: thin.reduce(Vector3D.zero, +).normalized) == nil)
        // Normals on one great circle span no cone
        let flat = ([[1, 0, 1], [-1, 0, 1], [0, 0, 1]] as [Vector3D]).map(\.normalized)
        #expect(OffsetCorners.coneSides(of: flat, around: [0, 0, 1]) == nil)
    }
}
