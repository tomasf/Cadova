import Foundation
import Testing
@testable import Cadova

struct EdgeSelectionTests {
    @Test func meshTopologyFromBox() async throws {
        // Use measuring to capture results from the readingEdges closure
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Encode counts in box dimensions
                Box(
                    x: Double(edges.topology.vertices.count),
                    y: Double(edges.topology.edges.count),
                    z: Double(edges.topology.triangles.count)
                ) as any Geometry3D
            }
            .measurements

        // A box has 8 vertices, 12 triangles (2 per face * 6 faces)
        // Edges: 12 box edges + 6 diagonal edges from triangulation = 18
        let vertexCount = Int(result.boundingBox!.size.x)
        let edgeCount = Int(result.boundingBox!.size.y)
        let triangleCount = Int(result.boundingBox!.size.z)

        #expect(vertexCount == 8)
        #expect(edgeCount == 18)
        #expect(triangleCount == 12)
    }

    @Test func sharpEdgeDetection() async throws {
        // Dihedral angle semantics:
        // - 0° = normals point same direction (coplanar faces, like diagonal edges on a flat box face)
        // - 90° = normals perpendicular (like box corner edges)
        // - 180° = normals point opposite (would be a "inside-out" edge)
        //
        // So "sharp" edges have angles AWAY from 0° (and 180°)
        // For a box: corner edges are ~90°, diagonal edges on flat faces are ~0°

        let result = try await Box(10)
            .readingEdges { _, edges in
                // Count edges with angles in different ranges
                let flatEdgeCount = edges.withDihedralAngle(in: 0°...10°).count // Near 0° = flat
                let cornerEdgeCount = edges.withDihedralAngle(in: 85°...95°).count // ~90° = box corners

                Box(x: Double(flatEdgeCount + 1), y: Double(cornerEdgeCount + 1), z: 1) as any Geometry3D
            }
            .measurements

        let flatEdgeCount = Int(result.boundingBox!.size.x) - 1
        let cornerEdgeCount = Int(result.boundingBox!.size.y) - 1

        // 6 diagonal edges (one per box face from triangulation) have ~0° dihedral
        #expect(flatEdgeCount == 6)
        // 12 box corner edges have ~90° dihedral
        #expect(cornerEdgeCount == 12)
    }

    @Test func dihedralAngleCalculation() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Find a sharp edge (box corner edge)
                let sharpEdges = edges.sharp(threshold: 100°).edges

                if let edge = sharpEdges.first,
                   let angle = edges.topology.dihedralAngle(for: edge) {
                    // Return box with size = angle in degrees
                    return Box(angle.degrees) as any Geometry3D
                }
                return Box(0) as any Geometry3D
            }
            .measurements

        // Box edges should be approximately 90°
        let angle = result.boundingBox!.size.x
        #expect(angle >= 89 && angle <= 91)
    }

    @Test func edgeChainingOnBox() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Get sharp edges and chain them
                let sharpEdges = edges.sharp(threshold: 100°)
                let chains = sharpEdges.chained(continuityThreshold: 30°)

                let chainCount = chains.count
                let allSingleEdge = chains.allSatisfy { $0.edges.count == 1 } ? 1.0 : 0.0
                return Box(x: Double(chainCount), y: allSingleEdge, z: 1) as any Geometry3D
            }
            .measurements

        // Box edges form 12 separate chains (each edge is its own chain since corners are 90°)
        // because the continuity threshold of 30° won't connect edges meeting at 90°
        let chainCount = Int(result.boundingBox!.size.x)
        let allSingleEdge = result.boundingBox!.size.y > 0.5

        #expect(chainCount == 12)
        #expect(allSingleEdge)
    }

    @Test func edgeChainingWithHighThreshold() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Get sharp edges and chain them with a high continuity threshold
                let sharpEdges = edges.sharp(threshold: 100°)
                let chains = sharpEdges.chained(continuityThreshold: 100°)

                let chainCount = chains.count
                let totalEdgesInChains = chains.reduce(0) { $0 + $1.edges.count }
                // Add 1 to avoid zero-size box
                return Box(x: Double(chainCount) + 1, y: Double(totalEdgesInChains) + 1, z: 1) as any Geometry3D
            }
            .measurements

        // With high threshold (100°), edges meeting at 90° corners should be chained
        // together, resulting in fewer chains than individual edges
        let chainCount = Int(result.boundingBox!.size.x) - 1
        let totalEdgesInChains = Int(result.boundingBox!.size.y) - 1

        // Should have fewer chains than edges (since some are chained together)
        #expect(chainCount < 12)
        // All 12 sharp edges should still be accounted for in the chains
        #expect(totalEdgesInChains == 12)
    }

    @Test func spatialFiltering() async throws {
        let result = try await Box(x: 20, y: 20, z: 10)
            .readingEdges { _, edges in
                let totalEdgeCount = edges.count

                // Filter edges within the upper half of the box
                let upperBox = BoundingBox3D(minimum: Vector3D(-15, -15, 5), maximum: Vector3D(15, 15, 15))
                let upperEdgeCount = edges.within(upperBox).count

                return Box(x: Double(upperEdgeCount), y: Double(totalEdgeCount), z: 1) as any Geometry3D
            }
            .measurements

        let upperEdgeCount = Int(result.boundingBox!.size.x)
        let totalEdgeCount = Int(result.boundingBox!.size.y)

        // Should find edges on the top face and upper parts of vertical edges
        #expect(upperEdgeCount > 0)
        #expect(upperEdgeCount < totalEdgeCount)
    }

    @Test func directionFiltering() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Filter for vertical edges (aligned with Z axis)
                let verticalEdgeCount = edges.aligned(with: .z, tolerance: 10°).count

                // Filter for horizontal edges (perpendicular to Z)
                let horizontalEdgeCount = edges.perpendicular(to: .z, tolerance: 10°).count

                return Box(x: Double(verticalEdgeCount), y: Double(horizontalEdgeCount), z: 1) as any Geometry3D
            }
            .measurements

        let verticalEdgeCount = Int(result.boundingBox!.size.x)
        let horizontalEdgeCount = Int(result.boundingBox!.size.y)

        // A box has 4 vertical edges
        #expect(verticalEdgeCount == 4)

        // A box has 8 horizontal edges (4 top + 4 bottom)
        // Plus diagonal edges from triangulation that lie in horizontal planes
        #expect(horizontalEdgeCount >= 8)
    }

    @Test func setOperations() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let sharpEdges = edges.sharp(threshold: 100°)
                let verticalEdges = edges.aligned(with: .z, tolerance: 10°)

                let sharpCount = sharpEdges.count

                // Intersection: sharp vertical edges
                let sharpVerticalCount = sharpEdges.intersection(verticalEdges).count

                // Subtracting: sharp edges that are not vertical
                let sharpNonVerticalCount = sharpEdges.subtracting(verticalEdges).count

                // Union should contain all edges from both sets
                let combinedCount = sharpEdges.union(verticalEdges).count

                // Pack results into a box
                // We need 4 values, so use volume creatively
                let packed = Double(sharpVerticalCount) * 1000000 + Double(sharpNonVerticalCount) * 1000 + Double(combinedCount) + Double(sharpCount) * 0.001

                return Box(packed) as any Geometry3D
            }
            .measurements

        // Unpack results
        let packed = Int(result.boundingBox!.size.x)
        let sharpVerticalCount = packed / 1000000
        let sharpNonVerticalCount = (packed % 1000000) / 1000
        let combinedCount = packed % 1000

        #expect(sharpVerticalCount == 4)
        #expect(sharpNonVerticalCount == 8)
        #expect(combinedCount == 12) // All vertical edges are sharp, so union == sharp count
    }

    @Test func readingEdgesIntegration() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let sharpCount = edges.sharp(threshold: 100°).count
                // Return a simple geometry based on the count
                return Box(Double(sharpCount)) as any Geometry3D
            }
            .measurements

        // The resulting box should have size 12 (number of sharp edges)
        #expect(result.volume ≈ (12.0 * 12.0 * 12.0))
    }

    @Test func edgeLengthFiltering() async throws {
        let result = try await Box(x: 10, y: 20, z: 30)
            .readingEdges { _, edges in
                // Filter for edges with length around 10 (short edges)
                let shortEdgeCount = edges.withLength(in: 9...11).count

                // Filter for long edges (around 30)
                let longEdgeCount = edges.withLength(in: 29...31).count

                return Box(x: Double(shortEdgeCount), y: Double(longEdgeCount), z: 1) as any Geometry3D
            }
            .measurements

        let shortEdgeCount = Int(result.boundingBox!.size.x)
        let longEdgeCount = Int(result.boundingBox!.size.y)

        // Should find the 4 edges along X dimension
        #expect(shortEdgeCount >= 4)

        // Should find the 4 edges along Z dimension
        #expect(longEdgeCount >= 4)
    }

    @Test func nearPointFiltering() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let totalCount = edges.count

                // Filter for edges near the top-front-right corner
                let cornerPoint = Vector3D(5, 5, 5)
                let nearCornerCount = edges.nearPoint(cornerPoint, distance: 6).count

                return Box(x: Double(nearCornerCount), y: Double(totalCount), z: 1) as any Geometry3D
            }
            .measurements

        let nearCornerCount = Int(result.boundingBox!.size.x)
        let totalCount = Int(result.boundingBox!.size.y)

        // Should find edges that have midpoints within 6 units of the corner
        #expect(nearCornerCount > 0)
        #expect(nearCornerCount < totalCount)
    }

    @Test func bisectorNormal() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Get a sharp edge (box corner)
                let sharpEdges = edges.sharp(threshold: 100°).edges

                guard let edge = sharpEdges.first,
                      let bisector = edges.topology.bisectorNormal(for: edge) else {
                    return Box(1) as any Geometry3D
                }

                // The bisector should be normalized (magnitude ~1)
                let magnitude = bisector.magnitude

                // For a box corner edge, the bisector should point diagonally outward
                // at 45° from each face. Its magnitude should be 1.
                return Box(x: magnitude + 1, y: 2, z: 1) as any Geometry3D
            }
            .measurements

        let magnitude = result.boundingBox!.size.x - 1

        // Bisector should be normalized
        #expect(magnitude >= 0.99 && magnitude <= 1.01)
    }

    @Test func readingEdgeChainsConvenience() async throws {
        let result = try await Box(10)
            .readingEdgeChains(sharpnessThreshold: 100°, continuityThreshold: 30°) { _, chains, _ in
                let chainCount = chains.count
                let totalEdgesInChains = chains.reduce(0) { $0 + $1.edges.count }
                Box(x: Double(chainCount), y: Double(totalEdgesInChains), z: 1) as any Geometry3D
            }
            .measurements

        let chainCount = Int(result.boundingBox!.size.x)
        let totalEdgesInChains = Int(result.boundingBox!.size.y)

        // 12 sharp edges, each in its own chain (30° threshold doesn't chain 90° corners)
        #expect(chainCount == 12)
        #expect(totalEdgesInChains == 12)
    }
}
