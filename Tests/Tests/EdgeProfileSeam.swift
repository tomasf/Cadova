import Foundation
import Testing
import Manifold3D
@testable import Cadova

/// Where a profile meets the wall it starts from.
///
/// Cutting a fillet out of a body leaves the boolean to resolve a cutter that leaves the wall
/// tangentially, nearly coplanar with it for its first facets. Along a faceted curve the engine
/// resolved that into a ring of degenerate triangles and unmerged near-duplicate vertices around
/// the bottom of the fillet. Prismatic bodies are now profiled by building the profiled part
/// directly on the wall's own vertices, so these tests look for those defects in the mesh itself.
struct EdgeProfileSeamTests {
    private struct MeshDefects {
        var degenerateTriangles = 0
        var nearDuplicateVertices = 0
    }

    private func defects(_ geometry: any Geometry3D) async throws -> MeshDefects {
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let mesh = try await context.result(for: result.node).concrete.meshGL()
        let vertices = mesh.vertices
        var defects = MeshDefects()

        for triangle in mesh.triangles {
            let a = vertices[triangle.a], b = vertices[triangle.b], c = vertices[triangle.c]
            if ((b - a) × (c - a)).magnitude / 2 < 1e-8 {
                defects.degenerateTriangles += 1
            }
        }

        struct Cell: Hashable { let x, y, z: Int64 }
        let size = 1e-4
        func cell(_ point: Vector3D) -> Cell {
            Cell(x: Int64((point.x / size).rounded(.down)), y: Int64((point.y / size).rounded(.down)), z: Int64((point.z / size).rounded(.down)))
        }
        var grid: [Cell: [Int]] = [:]
        for (index, point) in vertices.enumerated() {
            grid[cell(point), default: []].append(index)
        }
        for (index, point) in vertices.enumerated() {
            let base = cell(point)
            for dx in Int64(-1)...1 { for dy in Int64(-1)...1 { for dz in Int64(-1)...1 {
                for other in grid[Cell(x: base.x + dx, y: base.y + dy, z: base.z + dz)] ?? [] where other > index {
                    let distance = (vertices[other] - point).magnitude
                    if distance > 0, distance < size {
                        defects.nearDuplicateVertices += 1
                    }
                }
            }}}
        }
        return defects
    }

    /// The outline of the README's hex key holder, rounded hexagons hulled together
    private static var holderOutline: any Geometry2D {
        Stack(.x, spacing: 6, alignment: .centerY) {
            for size in [1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0] {
                RegularPolygon(sideCount: 6, widthAcrossFlats: size + 0.2)
            }
        }
        .offset(amount: 6, style: .round)
        .convexHull()
    }

    @Test func `a fillet on a curved extrusion meets the wall without slivers`() async throws {
        let found = try await defects(Self.holderOutline.extruded(height: 16, topEdge: .fillet(radius: 2), bottomEdge: .chamfer(depth: 1)))
        #expect(found.degenerateTriangles == 0)
        #expect(found.nearDuplicateVertices == 0)
    }

    @Test func `a fillet cut into a curved body meets the wall without slivers`() async throws {
        let found = try await defects(Cylinder(radius: 30, height: 10).cuttingEdgeProfile(.fillet(radius: 2), on: .top))
        #expect(found.degenerateTriangles == 0)
        #expect(found.nearDuplicateVertices == 0)
    }

    @Test func `concave corners and holes get fillets without slivers`() async throws {
        let plate = Circle(diameter: 50)
            .adding { Rectangle(x: 12, y: 30).aligned(at: .center).translated(x: 28) }
            .subtracting {
                Circle(diameter: 10).translated(x: -10)
                Circle(diameter: 10).translated(x: 10)
            }
        let found = try await defects(plate.extruded(height: 8, topEdge: .fillet(radius: 1.5)))
        #expect(found.degenerateTriangles == 0)
        #expect(found.nearDuplicateVertices == 0)

        // Concave corners and holes fan out into arcs; if those had the wrong shape, the volume
        // would drift away from the cut's, which follows the same erosion
        let built = try await plate.extruded(height: 8, topEdge: .fillet(radius: 1.5))
            .withDefaultSegmentation().measurements.volume
        let cut = try await plate.extruded(height: 8)
            .cuttingEdgeProfile(.fillet(radius: 1.5), on: .top, offset: 0, allowsDirectConstruction: false)
            .withDefaultSegmentation().measurements.volume
        #expect(abs(built - cut) / cut < 1e-4, "\(built) vs \(cut)")
    }

    /// The fillet removes the material it should. A regular polygon eroded by `d` is a smaller
    /// regular polygon, with its apothem reduced by `d`, so the expected volume can be integrated
    /// directly over the fillet's depth at each height.
    @Test func `a fillet removes exactly the material of its erosion`() async throws {
        let sides = 64
        let circumradius = 30.0
        let height = 10.0
        let radius = 3.0
        let apothem = circumradius * cos(.pi / Double(sides))
        func area(inset: Double) -> Double {
            Double(sides) * pow(apothem - inset, 2) * tan(.pi / Double(sides))
        }

        // Integrate the fillet band numerically; z runs up from where the fillet starts
        let steps = 10_000
        var filletVolume = 0.0
        for step in 0..<steps {
            let z = (Double(step) + 0.5) / Double(steps) * radius
            let depth = radius - (radius * radius - z * z).squareRoot()
            filletVolume += area(inset: depth) * radius / Double(steps)
        }
        let expected = area(inset: 0) * (height - radius) + filletVolume
        let removed = area(inset: 0) * height - expected

        let shape = RegularPolygon(sideCount: sides, circumradius: circumradius)
        for geometry in [
            shape.extruded(height: height, topEdge: .fillet(radius: radius)),
            shape.extruded(height: height).cuttingEdgeProfile(.fillet(radius: radius), on: .top),
        ] {
            let volume = try await geometry.withDefaultSegmentation().measurements.volume
            // The profile itself is faceted, so allow a small fraction of the removed volume
            #expect(abs(volume - expected) < removed * 0.01, "\(volume) vs \(expected)")
        }
    }

    /// Sharp corners and holes as tight as the profile are profiled to their exact erosion. The
    /// cut got both badly wrong: it removed about twice the material it should at a thin sliver's
    /// acute corner, and several times too much around holes whose radius matches the fillet. The
    /// exact volume integrates the outline's erosion at each height over the profile.
    @Test(arguments: [
        ("sliver", Polygon([[0, 0], [60, 0], [0, 4]]) as any Geometry2D, 1.0),
        ("plate", Rectangle(x: 50, y: 30)
            .aligned(at: .center)
            .rounded(radius: 4)
            .subtracting {
                Circle(diameter: 6).translated(x: 15).symmetry(over: .x)
                Rectangle(x: 10, y: 3).aligned(at: .center)
            }, 3.0),
    ])
    func `profiles follow the exact erosion around sharp corners and tight holes`(
        name: String, shape: any Geometry2D, radius: Double
    ) async throws {
        let height = 12.0
        let wallArea = try await shape.withDefaultSegmentation().measurements.area
        let steps = 200
        var expected = wallArea * (height - radius)
        for step in 0..<steps {
            let z = (Double(step) + 0.5) / Double(steps) * radius
            let depth = radius - (radius * radius - z * z).squareRoot()
            let area = try await shape.offset(amount: -depth, style: .round).withDefaultSegmentation().measurements.area
            expected += area * radius / Double(steps)
        }
        let removed = wallArea * height - expected

        let volume = try await shape.extruded(height: height, topEdge: .fillet(radius: radius))
            .withDefaultSegmentation().measurements.volume
        #expect(abs(volume - expected) < removed * 0.02, "\(name): \(volume) vs \(expected)")
    }

    /// Shapes the direct construction can't describe keep the cut, and come out exactly as before.
    /// Holes 8 mm across on a 12 mm pitch are left with nothing between them at a 2 mm fillet's
    /// full depth, and a cone isn't a prism at all.
    @Test func `shapes the direct construction can't describe keep the cut`() async throws {
        let tray = Rectangle(x: 40, y: 40)
            .aligned(at: .center)
            .subtracting {
                Circle(diameter: 8)
                    .translated(x: -6, y: -6)
                    .repeated(along: .x, step: 12, count: 2)
                    .repeated(along: .y, step: 12, count: 2)
            }
            .extruded(height: 10)
        let cone = Cylinder(bottomRadius: 20, topRadius: 15, height: 10)

        for body in [tray, cone] {
            let profiled = body.cuttingEdgeProfile(.fillet(radius: 2), on: .top)
            let cut = body.cuttingEdgeProfile(.fillet(radius: 2), on: .top, offset: 0, allowsDirectConstruction: false)
            let profiledVolume = try await profiled.withDefaultSegmentation().measurements.volume
            let cutVolume = try await cut.withDefaultSegmentation().measurements.volume
            #expect(profiledVolume == cutVolume)
        }
    }
}
