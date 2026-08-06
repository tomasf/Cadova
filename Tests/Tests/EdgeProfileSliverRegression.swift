import Foundation
import Testing
import Manifold3D
@testable import Cadova

/// Regression coverage for a real defect found in rc1's hub-brace part: a genuinely sharp
/// corner sitting close to a run of micro-segments left behind by `rounded(insideRadius:
/// outsideRadius:)` (then clipped by a later `.intersecting`) made `EdgeProfile.followingEdge`
/// leave a thin, fold-back sliver standing the height of the profile right at that seam. Smaller
/// hand-built repro shapes didn't reliably reproduce this — it needs roughly this much real
/// shape complexity to trigger reliably.
///
/// This spent a while disabled as flaky, on the reading that its remaining slivers were the
/// boolean engine resolving a coincidence inconsistently and nothing the construction could help.
/// That was wrong: the shape's mirrored spike tip turns inside a radius of about 0.53, well under
/// the chamfer's own 1mm depth, so the swept construction's rings crossed there and handed the
/// engine self-intersecting geometry — invalid input it was free to resolve differently each run,
/// which is what made the failures come and go. Building tightly curved cutting profiles from
/// offsets instead settled it, and incidentally made this test fast.
struct EdgeProfileSliverRegressionTests {
    private typealias MeshTriangle = Manifold3D.Triangle

    private func degenerateCount(_ geometry: any Geometry3D, thresholdDegrees: Double = 179) async throws -> Int {
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
        for (ti, t) in mesh.triangles.enumerated() {
            for (a, b) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)] {
                edgeMap[Int64(min(a, b)) << 32 | Int64(max(a, b)), default: []].append(ti)
            }
        }
        let thresh = cos(thresholdDegrees * .pi / 180)
        var count = 0
        for (_, list) in edgeMap where list.count == 2 {
            if normal(mesh.triangles[list[0]]) ⋅ normal(mesh.triangles[list[1]]) < thresh { count += 1 }
        }
        return count
    }

    @Test
    func `cut chamfer around a real-scale rounded-then-clipped outline has no slivers`() async throws {
        // Synthesizes the essential shape of rc1's frontHubBraceArea: a base shape with holes,
        // restricted to a y-range, unioned with a convex-hulled circle, rounded with different
        // inside/outside radii (densely tessellating the transitions into short segments), then
        // clipped by intersecting the original unrounded shape (reintroducing a genuinely sharp
        // corner immediately next to some of those short segments).
        let baseShape = Rectangle(x: 120, y: 200)
            .aligned(at: .centerX)
            .subtracting {
                Circle(diameter: 30).translated(x: 30, y: 100)
                Circle(diameter: 20).translated(x: -30, y: 50)
            }

        let outline = baseShape
            .within(y: 77.0...)
            .adding {
                Circle(diameter: 24)
                    .translated(x: 25)
                    .convexHull(adding: [15, 100])
                    .symmetry(over: .x)
            }
            .rounded(insideRadius: 25, outsideRadius: 8)
            .intersecting { baseShape }

        let geometry = outline.extruded(height: 8, topEdge: .chamfer(depth: 1.0))
        let degenerate = try await degenerateCount(geometry)
        #expect(degenerate == 0, "found \(degenerate) fold-back sliver edges")
    }
}
