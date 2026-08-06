import Foundation
import Testing
import Manifold3D
@testable import Cadova

/// A fillet whose radius rivals or exceeds the radius of curvature of the outline it follows.
///
/// Sweeping a cross-section along the outline can't describe this: each vertex's ring reaches
/// inward along its own miter ray, and once the profile is deep enough to pass the outline's own
/// center of curvature those rays cross, folding the swept surface through itself. The resulting
/// mesh isn't merely inaccurate but invalid, and the boolean engine resolves invalid input
/// differently from run to run — which is what made this show up as slivers that came and went
/// between otherwise identical runs.
struct EdgeProfileTightCurvatureTests {
    private typealias MeshTriangle = Manifold3D.Triangle

    /// Edges where the two triangles sharing them fold back on each other, which a valid surface
    /// never does.
    private func foldedEdgeCount(_ geometry: any Geometry3D) async throws -> Int {
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let mesh = try await context.result(for: result.node).concrete.meshGL()
        let verts = mesh.vertices
        func normal(_ t: MeshTriangle) -> Vector3D {
            let a = verts[t.a]
            let n = (verts[t.b] - a) × (verts[t.c] - a)
            let m = n.magnitude
            return m > 0 ? n / m : .zero
        }
        var edgeMap: [Int64: [Int]] = [:]
        for (index, triangle) in mesh.triangles.enumerated() {
            for (a, b) in [(triangle.a, triangle.b), (triangle.b, triangle.c), (triangle.c, triangle.a)] {
                edgeMap[Int64(min(a, b)) << 32 | Int64(max(a, b)), default: []].append(index)
            }
        }
        let threshold = cos(179 * Double.pi / 180)
        return edgeMap.values
            .filter { $0.count == 2 && normal(mesh.triangles[$0[0]]) ⋅ normal(mesh.triangles[$0[1]]) < threshold }
            .count
    }

    @Test(arguments: [(5.0, 8.0), (8.0, 7.0), (5.0, 5.0), (5.0, 6.0)])
    func `fillet larger than the corner it follows leaves no folded surface`(
        cornerRadius: Double, filletRadius: Double
    ) async throws {
        let geometry = Rectangle(Vector2D(40, 40))
            .cuttingEdgeProfile(.fillet(radius: cornerRadius))
            .extruded(height: 14, bottomEdge: .fillet(radius: filletRadius))

        let folded = try await foldedEdgeCount(geometry)
        #expect(folded == 0, "corner \(cornerRadius) / fillet \(filletRadius): \(folded) folded edges")
    }

    /// The floor left by the fillet is the outline eroded by the profile's full depth — the
    /// defining property of a rolling-ball fillet, and the one the swept construction gets wrong
    /// once the corner is too tight to hold the profile. Eroding this outline by 8 collapses its
    /// r=5 corners to sharp ones: (30×30 ⊕ disk 5) ⊖ disk 8 = 30×30 ⊖ disk 3, a 24×24 square.
    @Test func `fillet floor matches the outline's erosion`() async throws {
        let geometry = Rectangle(Vector2D(40, 40))
            .cuttingEdgeProfile(.fillet(radius: 5))
            .extruded(height: 14, bottomEdge: .fillet(radius: 8))

        for height in [0.05, 0.2] {
            let depth = 8 - (64 - (8 - height) * (8 - height)).squareRoot()
            let expected = pow(40 - 2 * depth, 2)
            let area = try await geometry.sliced(along: Plane.z(height)).measurements.area
            #expect(abs(area - expected) / expected < 0.005, "at z=\(height): \(area) vs \(expected)")
        }
    }

    /// The fillet surface follows the outline's erosion smoothly, without rippling around the
    /// corner where that erosion collapses the outline's own arc into a sharp vertex.
    ///
    /// Deviation is measured against the exact erosion at each height: eroding this outline by `u`
    /// gives a rounded rectangle of size `40 - 2u` whose corner radius is `5 - u`, or a sharp square
    /// once `u` passes 5. A construction that skins between sections without controlling how their
    /// vertices correspond passes the area check above — the sections themselves are right — while
    /// still visibly rippling in between, which is what this measures instead.
    @Test func `fillet surface follows the erosion without rippling`() async throws {
        let geometry = Rectangle(Vector2D(40, 40))
            .cuttingEdgeProfile(.fillet(radius: 5))
            .extruded(height: 14, bottomEdge: .fillet(radius: 8))

        for height in [0.5, 1.5, 3.0, 5.0, 7.0] {
            let depth = 8 - (64 - (8 - height) * (8 - height)).squareRoot()
            let half = 20 - depth
            let radius = max(5 - depth, 0)

            let context = _EvaluationContext()
            let sliced = geometry.sliced(along: Plane.z(height)).withDefaultSegmentation()
            let result = try await context.buildResult(for: sliced, in: .defaultEnvironment)
            let polygons = try await context.result(for: result.node).concrete.polygonList().polygons
            guard let contour = polygons.max(by: { $0.vertices.count < $1.vertices.count }) else {
                Issue.record("no contour at z=\(height)")
                continue
            }

            // Signed distance to a rounded rectangle centred on the outline.
            let deviation = contour.vertices.map { vertex -> Double in
                let corner = Vector2D(abs(vertex.x - 20), abs(vertex.y - 20))
                    - Vector2D(half - radius, half - radius)
                let outside = Vector2D(max(corner.x, 0), max(corner.y, 0)).magnitude
                return abs(outside + min(max(corner.x, corner.y), 0) - radius)
            }.max() ?? 0

            #expect(deviation < 0.02, "at z=\(height) the surface strays \(deviation) from the erosion")
        }
    }

    /// Repeated builds of the same tight-curvature model agree exactly. The invalid swept geometry
    /// this replaces did not: identical input produced different meshes run to run, so a model
    /// could look right one time and carry a visible sliver the next.
    @Test func `tight curvature builds deterministically`() async throws {
        let geometry = Rectangle(Vector2D(40, 40))
            .cuttingEdgeProfile(.fillet(radius: 5))
            .extruded(height: 14, bottomEdge: .fillet(radius: 8))

        var volumes: [Double] = []
        for _ in 0..<3 {
            volumes.append(try await geometry.measurements.volume)
        }
        #expect(Set(volumes).count == 1, "volumes varied between runs: \(volumes)")
    }
}
