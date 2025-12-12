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
                    y: Double(edges.topology.allSegments.count),
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
                // Count segments with angles in different ranges
                let flatSegmentCount = edges.withDihedralAngle(in: 0°...10°).segmentCount // Near 0° = flat
                let cornerSegmentCount = edges.withDihedralAngle(in: 85°...95°).segmentCount // ~90° = box corners

                Box(x: Double(flatSegmentCount + 1), y: Double(cornerSegmentCount + 1), z: 1) as any Geometry3D
            }
            .measurements

        let flatSegmentCount = Int(result.boundingBox!.size.x) - 1
        let cornerSegmentCount = Int(result.boundingBox!.size.y) - 1

        // 6 diagonal segments (one per box face from triangulation) have ~0° dihedral
        #expect(flatSegmentCount == 6)
        // 12 box corner segments have ~90° dihedral
        #expect(cornerSegmentCount == 12)
    }

    @Test func dihedralAngleCalculation() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Find a sharp segment (box corner segment)
                let sharpSegments = edges.sharp(threshold: 100°).segments

                if let segment = sharpSegments.first,
                   let angle = edges.topology.dihedralAngle(for: segment) {
                    // Return box with size = angle in degrees
                    Box(angle.degrees) as any Geometry3D
                } else {
                    Box(0) as any Geometry3D
                }
            }
            .measurements

        // Box segments should be approximately 90°
        let angle = result.boundingBox!.size.x
        #expect(angle >= 89 && angle <= 91)
    }

    @Test func edgeChainingOnBox() async throws {
        let result = try await Box(10)
            .readingEdges { _, selection in
                // Get sharp edges and build edges from them
                let sharpSelection = selection.sharp(threshold: 100°)
                let selectedEdges = sharpSelection.edges(continuityThreshold: 30°)

                let edgeCount = selectedEdges.count
                let allSingleSegment = selectedEdges.allSatisfy { $0.segments.count == 1 } ? 1.0 : 0.0
                return Box(x: Double(edgeCount), y: allSingleSegment, z: 1) as any Geometry3D
            }
            .measurements

        // Box edges form 12 separate edges (each is a single segment since corners are 90°)
        // because the continuity threshold of 30° won't connect segments meeting at 90°
        let edgeCount = Int(result.boundingBox!.size.x)
        let allSingleSegment = result.boundingBox!.size.y > 0.5

        #expect(edgeCount == 12)
        #expect(allSingleSegment)
    }

    @Test func edgeChainingWithHighThreshold() async throws {
        let result = try await Box(10)
            .readingEdges { _, selection in
                // Get sharp edges and build edges with a high continuity threshold
                let sharpSelection = selection.sharp(threshold: 100°)
                let selectedEdges = sharpSelection.edges(continuityThreshold: 100°)

                let edgeCount = selectedEdges.count
                let totalSegmentsInEdges = selectedEdges.reduce(0) { $0 + $1.segments.count }
                // Add 1 to avoid zero-size box
                return Box(x: Double(edgeCount) + 1, y: Double(totalSegmentsInEdges) + 1, z: 1) as any Geometry3D
            }
            .measurements

        // With high threshold (100°), segments meeting at 90° corners should be connected
        // together, resulting in fewer edges than individual segments
        let edgeCount = Int(result.boundingBox!.size.x) - 1
        let totalSegmentsInEdges = Int(result.boundingBox!.size.y) - 1

        // Should have fewer edges than segments (since some are connected)
        #expect(edgeCount < 12)
        // All 12 sharp segments should still be accounted for in the edges
        #expect(totalSegmentsInEdges == 12)
    }

    @Test func spatialFiltering() async throws {
        let result = try await Box(x: 20, y: 20, z: 10)
            .readingEdges { _, edges in
                let totalSegmentCount = edges.segmentCount

                // Filter segments within the upper half of the box
                let upperBox = BoundingBox3D(minimum: Vector3D(-15, -15, 5), maximum: Vector3D(15, 15, 15))
                let upperSegmentCount = edges.within(upperBox).segmentCount

                return Box(x: Double(upperSegmentCount), y: Double(totalSegmentCount), z: 1) as any Geometry3D
            }
            .measurements

        let upperSegmentCount = Int(result.boundingBox!.size.x)
        let totalSegmentCount = Int(result.boundingBox!.size.y)

        // Should find segments on the top face and upper parts of vertical edges
        #expect(upperSegmentCount > 0)
        #expect(upperSegmentCount < totalSegmentCount)
    }

    @Test func directionFiltering() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Filter for vertical segments (aligned with Z axis)
                let verticalSegmentCount = edges.aligned(with: .z, tolerance: 10°).segmentCount

                // Filter for horizontal segments (perpendicular to Z)
                let horizontalSegmentCount = edges.perpendicular(to: .z, tolerance: 10°).segmentCount

                return Box(x: Double(verticalSegmentCount), y: Double(horizontalSegmentCount), z: 1) as any Geometry3D
            }
            .measurements

        let verticalSegmentCount = Int(result.boundingBox!.size.x)
        let horizontalSegmentCount = Int(result.boundingBox!.size.y)

        // A box has 4 vertical segments
        #expect(verticalSegmentCount == 4)

        // A box has 8 horizontal segments (4 top + 4 bottom)
        // Plus diagonal segments from triangulation that lie in horizontal planes
        #expect(horizontalSegmentCount >= 8)
    }

    @Test func setOperations() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let sharpSelection = edges.sharp(threshold: 100°)
                let verticalSelection = edges.aligned(with: .z, tolerance: 10°)

                let sharpCount = sharpSelection.segmentCount

                // Intersection: sharp vertical segments
                let sharpVerticalCount = sharpSelection.intersection(verticalSelection).segmentCount

                // Subtracting: sharp segments that are not vertical
                let sharpNonVerticalCount = sharpSelection.subtracting(verticalSelection).segmentCount

                // Union should contain all segments from both sets
                let combinedCount = sharpSelection.union(verticalSelection).segmentCount

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
        #expect(combinedCount == 12) // All vertical segments are sharp, so union == sharp count
    }

    @Test func readingEdgesIntegration() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let sharpCount = edges.sharp(threshold: 100°).segmentCount
                // Return a simple geometry based on the count
                return Box(Double(sharpCount)) as any Geometry3D
            }
            .measurements

        // The resulting box should have size 12 (number of sharp segments)
        #expect(result.volume ≈ (12.0 * 12.0 * 12.0))
    }

    @Test func edgeLengthFiltering() async throws {
        let result = try await Box(x: 10, y: 20, z: 30)
            .readingEdges { _, edges in
                // Filter for segments with length around 10 (short segments)
                let shortSegmentCount = edges.withLength(in: 9...11).segmentCount

                // Filter for long segments (around 30)
                let longSegmentCount = edges.withLength(in: 29...31).segmentCount

                return Box(x: Double(shortSegmentCount), y: Double(longSegmentCount), z: 1) as any Geometry3D
            }
            .measurements

        let shortSegmentCount = Int(result.boundingBox!.size.x)
        let longSegmentCount = Int(result.boundingBox!.size.y)

        // Should find the 4 segments along X dimension
        #expect(shortSegmentCount >= 4)

        // Should find the 4 segments along Z dimension
        #expect(longSegmentCount >= 4)
    }

    @Test func nearPointFiltering() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                let totalCount = edges.segmentCount

                // Filter for segments near the top-front-right corner
                let cornerPoint = Vector3D(5, 5, 5)
                let nearCornerCount = edges.nearPoint(cornerPoint, distance: 6).segmentCount

                return Box(x: Double(nearCornerCount), y: Double(totalCount), z: 1) as any Geometry3D
            }
            .measurements

        let nearCornerCount = Int(result.boundingBox!.size.x)
        let totalCount = Int(result.boundingBox!.size.y)

        // Should find segments that have midpoints within 6 units of the corner
        #expect(nearCornerCount > 0)
        #expect(nearCornerCount < totalCount)
    }

    @Test func bisectorNormal() async throws {
        let result = try await Box(10)
            .readingEdges { _, edges in
                // Get a sharp segment (box corner)
                let sharpSegments = edges.sharp(threshold: 100°).segments

                if let segment = sharpSegments.first,
                   let bisector = edges.topology.bisectorNormal(for: segment) {
                    // The bisector should be normalized (magnitude ~1)
                    let magnitude = bisector.magnitude

                    // For a box corner segment, the bisector should point diagonally outward
                    // at 45° from each face. Its magnitude should be 1.
                    Box(x: magnitude + 1, y: 2, z: 1) as any Geometry3D
                } else {
                    Box(1) as any Geometry3D
                }
            }
            .measurements

        let magnitude = result.boundingBox!.size.x - 1

        // Bisector should be normalized
        #expect(magnitude >= 0.99 && magnitude <= 1.01)
    }

    @Test func readingSharpEdgesConvenience() async throws {
        let result = try await Box(10)
            .readingSharpEdges(sharpnessThreshold: 100°, continuityThreshold: 30°) { _, edges, _ in
                let edgeCount = edges.count
                let totalSegmentsInEdges = edges.reduce(0) { $0 + $1.segments.count }
                Box(x: Double(edgeCount), y: Double(totalSegmentsInEdges), z: 1) as any Geometry3D
            }
            .measurements

        let edgeCount = Int(result.boundingBox!.size.x)
        let totalSegmentsInEdges = Int(result.boundingBox!.size.y)

        // 12 sharp segments, each in its own edge (30° threshold doesn't connect 90° corners)
        #expect(edgeCount == 12)
        #expect(totalSegmentsInEdges == 12)
    }
}
