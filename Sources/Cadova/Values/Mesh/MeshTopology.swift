import Foundation
import Manifold3D

/// A mesh topology structure that provides efficient edge-to-face lookups.
///
/// This structure pre-computes adjacency information from a triangle mesh,
/// enabling O(1) lookup of which faces share a given edge segment.
///
public struct MeshTopology: Sendable {
    /// The vertices of the mesh.
    public let vertices: [Vector3D]

    /// The triangles of the mesh, each containing three vertex indices.
    public let triangles: [Manifold3D.Triangle]

    /// Maps each edge segment to the indices of triangles that share it.
    /// For a manifold mesh, each segment should have exactly 2 adjacent triangles.
    public let segmentToTriangles: [EdgeSegment: [Int]]

    /// All unique edge segments in the mesh.
    public let allSegments: [EdgeSegment]

    /// Pre-computed face normals for each triangle.
    public let faceNormals: [Vector3D]

    /// Creates a mesh topology from vertices and triangles.
    public init(vertices: [Vector3D], triangles: [Manifold3D.Triangle]) {
        self.vertices = vertices
        self.triangles = triangles

        // Build segment-to-triangle mapping
        var segmentMap: [EdgeSegment: [Int]] = [:]
        segmentMap.reserveCapacity(triangles.count * 3 / 2) // Euler's formula approximation

        for (triangleIndex, triangle) in triangles.enumerated() {
            let indices = [triangle.a, triangle.b, triangle.c]
            for i in 0..<3 {
                let segment = EdgeSegment(indices[i], indices[(i + 1) % 3])
                segmentMap[segment, default: []].append(triangleIndex)
            }
        }

        self.segmentToTriangles = segmentMap
        self.allSegments = Array(segmentMap.keys)

        // Pre-compute face normals
        self.faceNormals = triangles.map { triangle in
            let p0 = vertices[triangle.a]
            let p1 = vertices[triangle.b]
            let p2 = vertices[triangle.c]
            return ((p1 - p0) × (p2 - p0)).normalized
        }
    }

    /// Creates a mesh topology from a Manifold.
    public init(manifold: Manifold) {
        let mesh = manifold.readMesh()
        self.init(vertices: mesh.vertices, triangles: mesh.triangles)
    }
}

public extension MeshTopology {
    /// Returns the triangles adjacent to the given segment.
    func adjacentTriangles(for segment: EdgeSegment) -> [Int] {
        segmentToTriangles[segment] ?? []
    }

    /// Returns whether the segment is a boundary segment (only one adjacent triangle).
    func isBoundarySegment(_ segment: EdgeSegment) -> Bool {
        adjacentTriangles(for: segment).count == 1
    }

    /// Returns whether the segment is a manifold segment (exactly two adjacent triangles).
    func isManifoldSegment(_ segment: EdgeSegment) -> Bool {
        adjacentTriangles(for: segment).count == 2
    }

    /// Calculates the dihedral angle between the two faces sharing a segment.
    ///
    /// The dihedral angle is the angle between the face normals.
    /// - For a flat surface, the angle is 180° (normals point the same direction).
    /// - For a sharp 90° edge, the angle is 90°.
    /// - For a very sharp edge, the angle approaches 0°.
    ///
    /// - Parameter segment: The segment to calculate the dihedral angle for.
    /// - Returns: The dihedral angle, or `nil` if the segment doesn't have exactly 2 adjacent faces.
    ///
    func dihedralAngle(for segment: EdgeSegment) -> Angle? {
        let triangleIndices = adjacentTriangles(for: segment)
        guard triangleIndices.count == 2 else { return nil }

        let n0 = faceNormals[triangleIndices[0]]
        let n1 = faceNormals[triangleIndices[1]]

        // The dot product of normals gives cos(angle between normals)
        // For outward-facing normals on a convex edge, normals point away from each other
        let dotProduct = n0 ⋅ n1
        return acos(dotProduct.clamped(to: -1...1))
    }

    /// Returns whether the segment is "sharp" based on the dihedral angle threshold.
    ///
    /// A "sharp" segment is one where the dihedral angle is significantly different from both
    /// 0° (coplanar faces) and 180° (impossible for outward-facing normals).
    ///
    /// - Parameters:
    ///   - segment: The segment to check.
    ///   - threshold: The maximum dihedral angle for a segment to be considered sharp.
    ///     Defaults to 170°. Segments with angles between 10° and `threshold` are sharp.
    /// - Returns: `true` if the segment is sharp, `false` otherwise.
    ///
    func isSharpSegment(_ segment: EdgeSegment, threshold: Angle = 170°) -> Bool {
        guard let angle = dihedralAngle(for: segment) else { return false }
        // Segments near 0° are on flat surfaces (coplanar triangles), not sharp
        return angle > 10° && angle < threshold
    }

    /// Returns the outward-pointing bisector normal for a segment.
    ///
    /// The bisector normal is the direction perpendicular to the segment that bisects
    /// the two adjacent face normals. This is the direction an edge profile (chamfer,
    /// fillet, etc.) would "bulge" outward toward.
    ///
    /// - Parameter segment: The segment to get the bisector normal for.
    /// - Returns: The normalized bisector direction, or `nil` if the segment doesn't have
    ///   exactly 2 adjacent faces.
    ///
    func bisectorNormal(for segment: EdgeSegment) -> Vector3D? {
        let triangleIndices = adjacentTriangles(for: segment)
        guard triangleIndices.count == 2 else { return nil }

        let n0 = faceNormals[triangleIndices[0]]
        let n1 = faceNormals[triangleIndices[1]]

        // The bisector is the sum of the two normals, normalized
        let bisector = n0 + n1
        let magnitude = bisector.magnitude

        // If normals point in opposite directions, bisector is zero
        guard magnitude > 1e-10 else { return nil }

        return bisector / magnitude
    }
}
