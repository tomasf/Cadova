import Foundation
import Testing
import Manifold3D
@testable import Cadova

/// Mesh-quality checks for EdgeProfile's swept tools: the cut/fill surfaces must land exactly
/// where the profile says, and curved sweeps must not leave spurious feature edges — short
/// transverse "ticks" across the profiled band — at segment seams, where a viewer drawing
/// edges above a dihedral threshold would show lines on what should read as a smooth band.
struct EdgeProfileQualityTests {
    private typealias MeshTriangle = Manifold3D.Triangle

    private struct SharpEdge {
        let a: Vector3D
        let b: Vector3D
        let angleDegrees: Double
        var length: Double { (b - a).magnitude }
        var zSpan: Double { abs(a.z - b.z) }
    }

    /// All two-triangle edges whose face normals differ by more than the threshold —
    /// the same criterion viewers use to render feature edges.
    private func sharpEdges(_ geometry: any Geometry3D, thresholdDegrees: Double = 30) async throws -> [SharpEdge] {
        let context = EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let mesh = try await context.result(for: result.node).concrete.meshGL()
        let vertices = mesh.vertices

        func normal(_ t: MeshTriangle) -> Vector3D {
            let a = vertices[t.a]
            let n = (vertices[t.b] - a) × (vertices[t.c] - a)
            let magnitude = n.magnitude
            return magnitude > 0 ? n / magnitude : .zero
        }

        var edgeTriangles: [Int64: [Int]] = [:]
        for (index, triangle) in mesh.triangles.enumerated() {
            for (a, b) in [(triangle.a, triangle.b), (triangle.b, triangle.c), (triangle.c, triangle.a)] {
                edgeTriangles[Int64(min(a, b)) << 32 | Int64(max(a, b)), default: []].append(index)
            }
        }

        let threshold = cos(thresholdDegrees * .pi / 180)
        var found: [SharpEdge] = []
        for (key, list) in edgeTriangles where list.count == 2 {
            let d = normal(mesh.triangles[list[0]]) ⋅ normal(mesh.triangles[list[1]])
            if d < threshold {
                found.append(SharpEdge(
                    a: vertices[Int(key >> 32)],
                    b: vertices[Int(key & 0xFFFFFFFF)],
                    angleDegrees: acos(max(-1, min(1, d))) * 180 / .pi
                ))
            }
        }
        return found
    }

    @Test func `cut chamfer removes the exact closed-form volume`() async throws {
        // Chamfer depth 1 on a 20×20 box top removes (perimeter × 1/2) − 4 × (1/3)
        let volume = try await Box(x: 20, y: 20, z: 5)
            .cuttingEdgeProfile(.chamfer(depth: 1), on: .top)
            .measurements.volume
        #expect(abs(volume - (2000.0 - (40.0 - 4.0 / 3.0))) < 1e-6)
    }

    @Test func `formed chamfer adds the exact closed-form volume`() async throws {
        // A 45° skirt around a 20×20 box top adds (perimeter × 1/2) + 4 × (1/3),
        // less the interface margin by which the skirt stays shy of the top face.
        let volume = try await Box(x: 20, y: 20, z: 5)
            .formingEdgeProfile(.chamfer(depth: 1), on: .top)
            .measurements.volume
        #expect(abs(volume - (2000.0 + 40.0 + 4.0 / 3.0)) < 1e-3)
    }

    @Test func `chamfer along a curved edge leaves no seam ticks`() async throws {
        for segments in [32, 64] {
            let geometry = Cylinder(diameter: 20, height: 5)
                .cuttingEdgeProfile(.chamfer(depth: 1), on: .top)
                .withSegmentation(count: segments)
            let ticks = try await sharpEdges(geometry).filter { $0.length > 0.01 && $0.zSpan > 1e-3 }
            #expect(ticks.isEmpty, "seam ticks at \(segments) segments: \(ticks.count)")
        }
    }

    @Test func `formed chamfer on a hole tool leaves no seam ticks`() async throws {
        // A hole tool with a countersink-like flare formed on its top edge, then subtracted —
        // both the tool itself and the subtraction result must be free of transverse seam edges.
        let tool = Cylinder(diameter: 8, height: 5)
            .formingEdgeProfile(.chamfer(depth: 0.6), on: .top)
            .withSegmentation(count: 64)
        let toolTicks = try await sharpEdges(tool).filter {
            $0.length > 0.01 && $0.zSpan > 1e-3 && min($0.a.z, $0.b.z) > 0.1 && max($0.a.z, $0.b.z) < 4.9999
        }
        #expect(toolTicks.isEmpty, "tool seam ticks: \(toolTicks.count)")

        let result = Box(x: 30, y: 30, z: 5)
            .aligned(at: .centerXY)
            .subtracting {
                Cylinder(diameter: 8, height: 5)
                    .formingEdgeProfile(.chamfer(depth: 0.6), on: .top)
            }
            .withSegmentation(count: 64)
        let ticks = try await sharpEdges(result).filter {
            $0.length > 0.01 && $0.zSpan > 1e-3 && min($0.a.z, $0.b.z) > 0.1
        }
        #expect(ticks.isEmpty, "result seam ticks: \(ticks.count)")
    }
}
