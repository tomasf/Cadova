import Foundation
import Testing
@testable import Cadova

struct EdgeChainProfilingTests {
    @Test func chamferAllEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0

        // Apply chamfer to all sharp edges of a box
        let result = try await Box(20)
            .cuttingEdgeProfile(.chamfer(depth: 2), sharpnessThreshold: 100°)
            .measurements

        // Should produce valid geometry
        #expect(result.boundingBox != nil)

        // Volume must be reduced by chamfering
        #expect(result.volume < originalVolume, "Chamfer should reduce volume, got \(result.volume) vs original \(originalVolume)")

        // Volume should be reduced noticeably (at least 1% for a 2mm chamfer on 20mm box)
        #expect(result.volume < originalVolume * 0.99, "Volume reduction too small: \(result.volume)")

        // But not too much (chamfer shouldn't remove more than ~10% for reasonable depth)
        #expect(result.volume > originalVolume * 0.90, "Volume reduction too large: \(result.volume)")
    }

    @Test func filletAllEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0

        // Apply fillet to all sharp edges of a box
        let result = try await Box(20)
            .cuttingEdgeProfile(.fillet(radius: 2), sharpnessThreshold: 100°)
            .measurements

        // Should produce valid geometry
        #expect(result.boundingBox != nil)

        // Volume must be reduced by filleting
        #expect(result.volume < originalVolume, "Fillet should reduce volume")

        // Volume should be reduced noticeably
        #expect(result.volume < originalVolume * 0.99, "Volume reduction too small: \(result.volume)")

        // But not too much
        #expect(result.volume > originalVolume * 0.90, "Volume reduction too large: \(result.volume)")
    }

    @Test func chamferSpecificEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0

        // Use readingEdges to apply chamfer only to vertical edges
        let result = try await Box(20)
            .readingEdges { geometry, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                geometry.cuttingEdgeProfile(.chamfer(depth: 2), along: verticalChains, in: edges.topology)
            }
            .measurements

        // Should produce valid geometry
        #expect(result.boundingBox != nil)

        // Volume must be reduced - vertical chamfers should remove material along full height
        #expect(result.volume < originalVolume, "Chamfer should reduce volume")
        #expect(result.volume < originalVolume * 0.995, "Volume reduction too small: \(result.volume)")
    }

    @Test func directSubtractionAllEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0
        let result = try await Box(20)
            .readingConcrete { (manifold: Manifold) in
                let topology = MeshTopology(manifold: manifold)
                let chains = EdgeSelection(topology).sharp(threshold: 100°).chained()
                let profileGeom = chains.mapUnion { chain in
                    chain.profileGeometry(.chamfer(depth: 2), in: topology, type: .subtraction)
                }
                Box(20).subtracting { profileGeom }
            }
            .measurements
        #expect(result.volume < originalVolume, "ALL edges: got \(result.volume)")
    }

    @Test func directSubtractionVerticalEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0
        let result = try await Box(20)
            .readingConcrete { (manifold: Manifold) in
                let topology = MeshTopology(manifold: manifold)
                let chains = EdgeSelection(topology).sharp(threshold: 100°).aligned(with: .z, tolerance: 10°).chained()
                let profileGeom = chains.mapUnion { chain in
                    chain.profileGeometry(.chamfer(depth: 2), in: topology, type: .subtraction)
                }
                Box(20).subtracting { profileGeom }
            }
            .measurements
        #expect(result.volume < originalVolume, "VERTICAL edges: got \(result.volume)")
    }

    @Test func simpleCylinderSubtractionAtVerticalEdge() async throws {
        // Test that we CAN subtract something along a vertical edge manually
        let originalVolume = 20.0 * 20.0 * 20.0

        // Manually place a small cylinder at one vertical edge corner
        let result = try await Box(20)
            .subtracting {
                // Small cylinder at corner (20, 20, z) running along Z
                Cylinder(radius: 2, height: 30)
                    .translated(x: 20, y: 20, z: -5)
            }
            .measurements

        #expect(result.volume < originalVolume, "Simple cylinder subtraction should work, got \(result.volume)")
    }

    @Test func verticalProfileGeometryIsManifold() async throws {
        // Check if the profile geometry for vertical edges produces valid manifold
        let result = try await Box(20)
            .readingEdges { _, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                // Get just ONE chain
                guard let chain = verticalChains.first else {
                    return Box(0) as any Geometry3D
                }

                // Generate profile for just one edge
                return chain.profileGeometry(.chamfer(depth: 2), in: edges.topology, type: .subtraction)
            }
            .measurements

        #expect(result.volume > 0, "Single vertical edge profile should have volume, got \(result.volume)")
        #expect(result.boundingBox != nil, "Profile should have bounds")
    }

    @Test func directSubtractionHorizontalEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0
        let result = try await Box(20)
            .readingConcrete { (manifold: Manifold) in
                let topology = MeshTopology(manifold: manifold)
                let chains = EdgeSelection(topology).sharp(threshold: 100°).perpendicular(to: .z, tolerance: 10°).chained()
                let profileGeom = chains.mapUnion { chain in
                    chain.profileGeometry(.chamfer(depth: 2), in: topology, type: .subtraction)
                }
                Box(20).subtracting { profileGeom }
            }
            .measurements
        #expect(result.volume < originalVolume, "HORIZONTAL edges: got \(result.volume)")
    }

    @Test func filletVerticalEdges() async throws {
        let originalVolume = 20.0 * 20.0 * 20.0

        // First, verify we're finding vertical edges correctly
        let diagnostics = try await Box(20)
            .readingEdges { _, edges in
                let sharpEdges = edges.sharp(threshold: 100°)
                let verticalEdges = sharpEdges.aligned(with: .z, tolerance: 10°)
                let chains = verticalEdges.chained()

                // Encode counts in a box
                Box(
                    x: Double(sharpEdges.count),
                    y: Double(verticalEdges.count),
                    z: Double(chains.count)
                ) as any Geometry3D
            }
            .measurements

        let sharpCount = Int(diagnostics.boundingBox!.size.x)
        let verticalCount = Int(diagnostics.boundingBox!.size.y)
        let chainCount = Int(diagnostics.boundingBox!.size.z)

        #expect(sharpCount == 12, "Box should have 12 sharp edges, got \(sharpCount)")
        #expect(verticalCount == 4, "Box should have 4 vertical edges, got \(verticalCount)")
        #expect(chainCount == 4, "Should have 4 chains (one per vertical edge), got \(chainCount)")

        // Now test the actual profiling
        let result = try await Box(20)
            .readingEdges { geometry, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                geometry.cuttingEdgeProfile(.fillet(radius: 2), along: verticalChains, in: edges.topology)
            }
            .measurements

        // Should produce valid geometry
        #expect(result.boundingBox != nil)

        // Volume must be reduced noticeably - fillet removes material along full 20-unit height
        // Material removed per edge = r²(1 - π/4) * height = 4 * 0.215 * 20 ≈ 17.2 per edge
        // 4 edges: ~69 cubic units removed, so ~0.86% reduction
        #expect(result.volume < originalVolume, "Fillet should reduce volume, got \(result.volume)")
        #expect(result.volume < originalVolume * 0.995, "Volume reduction too small: \(result.volume) (expected < \(originalVolume * 0.995))")
        #expect(result.volume > originalVolume * 0.90, "Volume reduction too large: \(result.volume)")
    }

    @Test func profileGeometryGeneration() async throws {
        // Test that edge chain generates profile geometry correctly
        let result = try await Box(20)
            .readingEdges { _, edges in
                let sharpChains = edges
                    .sharp(threshold: 100°)
                    .chained(continuityThreshold: 30°)

                // Generate profile geometry for visualization
                let profileGeom = sharpChains.mapUnion { chain in
                    chain.profileGeometry(.chamfer(depth: 2), in: edges.topology, type: .subtraction)
                }

                profileGeom
            }
            .measurements

        // Profile geometry should have valid bounds
        #expect(result.boundingBox != nil)

        // Profile geometry should span beyond the box edges
        let size = result.boundingBox!.size
        #expect(size.x > 0)
        #expect(size.y > 0)
        #expect(size.z > 0)

        // Profile geometry should have substantial volume (chamfers on 12 edges of a 20-unit box)
        #expect(result.volume > 0, "Profile geometry should have volume")
    }

    @Test func verticalEdgeDiagnostics() async throws {
        // Diagnostic test to understand vertical edge properties
        let result = try await Box(20)
            .readingEdges { _, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                // Get info about the first vertical chain
                guard let chain = verticalChains.first else {
                    return Box(0) as any Geometry3D
                }

                let vertexIndices = chain.vertexIndices()
                let vertices = vertexIndices.map { edges.topology.vertices[$0] }

                // Encode: x = edge count, y = vertex count, z = chain length
                let chainLength = chain.length(in: edges.topology)

                // Also encode first vertex Z and last vertex Z in the volume
                let firstZ = vertices.first?.z ?? 0
                let lastZ = vertices.last?.z ?? 0

                // Return diagnostics encoded in geometry
                // Use translation to encode vertex Z positions
                return Box(x: Double(chain.edges.count), y: Double(vertices.count), z: chainLength)
                    .translated(x: firstZ, y: lastZ, z: 0) as any Geometry3D
            }
            .measurements

        let bounds = result.boundingBox!
        let edgeCount = Int(bounds.size.x)
        let vertexCount = Int(bounds.size.y)
        let chainLength = bounds.size.z
        let firstZ = bounds.center.x - bounds.size.x / 2  // Recover translation
        let lastZ = bounds.center.y - bounds.size.y / 2

        #expect(edgeCount == 1, "Each vertical chain should have 1 edge, got \(edgeCount)")
        #expect(vertexCount == 2, "Each vertical chain should have 2 vertices, got \(vertexCount)")
        #expect(chainLength >= 19.9 && chainLength <= 20.1, "Chain length should be ~20, got \(chainLength)")

        // Box(20) is centered, so Z should span -10 to +10
        // Note: min/max Z could be in either order
        let zSpan = Swift.abs(lastZ - firstZ)
        #expect(zSpan >= 19.9, "Z span should be ~20, got \(zSpan) (firstZ=\(firstZ), lastZ=\(lastZ))")
    }

    @Test func verticalProfileGeometryGeneration() async throws {
        // Test profile geometry for vertical edges specifically
        let result = try await Box(20)
            .readingEdges { _, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                // Generate profile geometry for vertical edges only
                let profileGeom = verticalChains.mapUnion { chain in
                    chain.profileGeometry(.fillet(radius: 2), in: edges.topology, type: .subtraction)
                }

                profileGeom
            }
            .measurements

        // Profile geometry should have valid bounds
        #expect(result.boundingBox != nil, "Profile geometry should have bounds")

        let bounds = result.boundingBox!
        let size = bounds.size

        // Profile geometry should span the full height of the box (20 units + overshoot)
        #expect(size.z >= 20, "Profile should span full height, got z=\(size.z). Bounds: min=\(bounds.minimum), max=\(bounds.maximum)")

        // Profile geometry should have substantial volume
        // The negative shape is an L (rectangle - quarter-circle), not the quarter-cylinder itself
        // For radius 2: L-area = 2×2 - π×4/4 = 4 - π ≈ 0.86 per edge
        // 4 edges × 0.86 × ~24 (height with overshoot) ≈ 82.6
        #expect(result.volume > 50, "Profile geometry should have significant volume, got \(result.volume). Bounds: min=\(bounds.minimum), max=\(bounds.maximum)")
    }

    @Test func emptyChainHandling() async throws {
        // Test with geometry that has no sharp edges meeting threshold
        let result = try await Sphere(radius: 10)
            .cuttingEdgeProfile(.chamfer(depth: 1), sharpnessThreshold: 10°)
            .measurements

        // Should still produce valid geometry (unchanged sphere)
        #expect(result.boundingBox != nil)
    }

    @Test func verticalProfileIntersectsBox() async throws {
        // Check if vertical edge profile actually overlaps with the box
        let result = try await Box(20)
            .readingEdges { _, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                let profileGeom = verticalChains.mapUnion { chain in
                    chain.profileGeometry(.chamfer(depth: 2), in: edges.topology, type: .subtraction)
                }

                // Intersect profile geometry with the box
                let intersection = Box(20).intersecting { profileGeom }

                intersection
            }
            .measurements

        // If profiles are positioned correctly, the intersection should have volume
        #expect(result.volume > 0, "Profile geometry should intersect with box, got volume \(result.volume)")
    }

    @Test func singleVerticalProfilePosition() async throws {
        // Check position of a single vertical edge's profile
        let result = try await Box(20)
            .readingEdges { _, edges in
                let verticalChains = edges
                    .sharp(threshold: 100°)
                    .aligned(with: .z, tolerance: 10°)
                    .chained()

                guard let chain = verticalChains.first else {
                    return Box(0) as any Geometry3D
                }

                // Get profile for single edge
                let profileGeom = chain.profileGeometry(.chamfer(depth: 2), in: edges.topology, type: .subtraction)

                // Return the profile, not an intersection
                return profileGeom
            }
            .measurements

        let bounds = result.boundingBox!
        // Profile should be positioned at one of the box corners
        // Box(20) spans (0,0,0) to (20,20,20)
        // Profile should overlap with that range in some way
        let minX = bounds.minimum.x
        let maxX = bounds.maximum.x
        let minY = bounds.minimum.y
        let maxY = bounds.maximum.y

        // Profile should extend from near 0 or 20 in both X and Y (depending on which corner)
        let overlapsBoxX = (minX < 20 && maxX > 0)
        let overlapsBoxY = (minY < 20 && maxY > 0)

        #expect(overlapsBoxX, "Profile should overlap box in X: min=\(minX), max=\(maxX)")
        #expect(overlapsBoxY, "Profile should overlap box in Y: min=\(minY), max=\(maxY)")

        // Also check Z range
        let minZ = bounds.minimum.z
        let maxZ = bounds.maximum.z
        #expect(minZ <= 0 && maxZ >= 20, "Profile should span full height: z=[\(minZ), \(maxZ)]")
    }

    @Test func continuityThresholdEffect() async throws {
        // Test that continuity threshold affects chain grouping
        let lowThresholdResult = try await Box(20)
            .readingEdges { _, edges in
                let chains = edges
                    .sharp(threshold: 100°)
                    .chained(continuityThreshold: 30°)

                // Return count encoded in box size
                Box(Double(chains.count)) as any Geometry3D
            }
            .measurements

        let highThresholdResult = try await Box(20)
            .readingEdges { _, edges in
                let chains = edges
                    .sharp(threshold: 100°)
                    .chained(continuityThreshold: 100°)

                // Return count encoded in box size
                Box(Double(chains.count)) as any Geometry3D
            }
            .measurements

        let lowCount = Int(lowThresholdResult.boundingBox!.size.x)
        let highCount = Int(highThresholdResult.boundingBox!.size.x)

        // With higher threshold, edges should be more connected, resulting in fewer chains
        #expect(highCount <= lowCount)
    }
}
