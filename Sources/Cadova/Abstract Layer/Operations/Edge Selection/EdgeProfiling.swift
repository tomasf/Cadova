import Foundation

public extension Edge {
    /// Creates a 3D geometry representing the profile swept along this edge.
    ///
    /// The profile is positioned and oriented at each segment using the mesh topology's
    /// bisector normal, and adapted to each segment's dihedral angle.
    ///
    /// - Parameters:
    ///   - profile: The edge profile to sweep along the edge.
    ///   - topology: The mesh topology containing vertex positions and segment information.
    ///   - type: Whether this is for addition or subtraction operations.
    /// - Returns: A 3D geometry representing the swept profile.
    ///
    func profileGeometry(
        _ profile: EdgeProfile,
        in topology: MeshTopology,
        type: EnvironmentValues.Operation
    ) -> any Geometry3D {
        guard !segments.isEmpty else { return Empty() }

        // Get ordered vertices for the edge
        let vertexIndices = self.vertexIndices()
        guard vertexIndices.count >= 2 else { return Empty() }

        let vertices = vertexIndices.map { topology.vertices[$0] }

        // Generate profile geometry for each segment
        return segments.enumerated().mapUnion { segmentIndex, segment in
            // Get segment geometry info
            let dihedralAngle = topology.dihedralAngle(for: segment) ?? 90°

            // Get face normals for consistent orientation
            // Sort triangle indices for deterministic behavior
            let triangleIndices = topology.adjacentTriangles(for: segment).sorted()
            guard triangleIndices.count == 2 else {
                return Empty() as any Geometry3D
            }
            let n0 = topology.faceNormals[triangleIndices[0]]
            let n1 = topology.faceNormals[triangleIndices[1]]

            // Get the segment endpoints (in edge order, with wrapping for closed edges)
            let startVertex = Self.vertex(at: segmentIndex, in: vertices, isClosed: self.isClosed)
            let endVertex = Self.vertex(at: segmentIndex + 1, in: vertices, isClosed: self.isClosed)
            let segmentVector = endVertex - startVertex
            let segmentLength = segmentVector.magnitude

            guard segmentLength > 1e-10 else {
                return Empty() as any Geometry3D
            }

            let tangent = segmentVector / segmentLength

            // Create profile negative shape for this segment's angle
            return profile.readingNegativeShape(for: dihedralAngle) { negativeShape, profileSize in
                // Extrude to unit length
                let unitProfile = negativeShape.extruded(height: 1.0)

                // Build transform to position and orient the profile
                let transform = Self.profileTransform(
                    tangent: tangent,
                    faceNormal0: n0,
                    faceNormal1: n1,
                    at: startVertex
                )

                // Scale, transform, and position the profile
                let overshoot = segmentLength * 0.1
                let profileGeom = unitProfile
                    .scaled(z: segmentLength + 2 * overshoot)
                    .translated(z: -overshoot)
                    .transformed(transform)

                // Trim at start and end vertices if not at edge endpoints
                self.trimProfile(
                    profileGeom,
                    segmentIndex: segmentIndex,
                    vertices: vertices,
                    type: type
                )
            }
        }
    }

    /// Gets a vertex by index with wrapping for closed edges.
    private static func vertex(at index: Int, in vertices: [Vector3D], isClosed: Bool) -> Vector3D {
        if isClosed {
            let count = vertices.count
            return vertices[((index % count) + count) % count]
        } else {
            return vertices[index]
        }
    }

    /// Computes the transform to position a profile at a segment.
    ///
    /// The profile's negative shape (L-shape = wedge minus chamfer) occupies the -X, -Y quadrant.
    /// When subtracted from the box, it removes material everywhere EXCEPT the chamfer area.
    ///
    /// For this to work, the L-shape must overlap with box material (which is on the
    /// INSIDE of both faces, opposite to face normals).
    ///
    /// So: profile's -X,-Y region should point INTO the solid.
    /// This means localX and localY should point OUTWARD (along face normals),
    /// so that -localX and -localY point inward.
    ///
    private static func profileTransform(
        tangent: Vector3D,
        faceNormal0: Vector3D,
        faceNormal1: Vector3D,
        at position: Vector3D
    ) -> Transform3D {
        // Project face normals onto the plane perpendicular to the segment
        var n0Proj = (faceNormal0 - (faceNormal0 ⋅ tangent) * tangent)
        var n1Proj = (faceNormal1 - (faceNormal1 ⋅ tangent) * tangent)

        let n0ProjMag = n0Proj.magnitude
        guard n0ProjMag > 1e-10 else {
            return .translation(position)
        }

        // Check handedness: n0 × n1 should be parallel to tangent for a right-handed system.
        // If anti-parallel, swap n0 and n1 so that tangent × n0 points toward n1.
        let crossProduct = n0Proj × n1Proj
        if crossProduct ⋅ tangent < 0 {
            swap(&n0Proj, &n1Proj)
        }

        // localX points OUTWARD along n0's direction (so -X points into solid)
        let localX = n0Proj.normalized

        // localY is perpendicular to both tangent and localX (right-handed system)
        // With the handedness check above, this should align with n1's direction
        let localY = (tangent × localX).normalized
        let localZ = tangent.normalized

        return Transform3D(
            orthonormalBasisOrigin: position,
            x: Direction3D(localX),
            y: Direction3D(localY),
            z: Direction3D(localZ)
        )
    }

    /// Trims the profile geometry at the start and end of a segment.
    private func trimProfile(
        _ profile: any Geometry3D,
        segmentIndex: Int,
        vertices: [Vector3D],
        type: EnvironmentValues.Operation
    ) -> any Geometry3D {
        var result: any Geometry3D = profile
        let segmentCount = segments.count

        // Trim at start vertex
        if isClosed || segmentIndex > 0 {
            let prevVertex = Self.vertex(at: segmentIndex - 1, in: vertices, isClosed: isClosed)
            let currentVertex = Self.vertex(at: segmentIndex, in: vertices, isClosed: isClosed)
            let nextVertex = Self.vertex(at: segmentIndex + 1, in: vertices, isClosed: isClosed)

            let prevDir = (currentVertex - prevVertex).normalized
            let nextDir = (nextVertex - currentVertex).normalized

            // Bisector plane at start vertex
            let bisectorDir = (prevDir + nextDir).normalized
            let trimPlane = Plane(offset: currentVertex, normal: Direction3D(bisectorDir))

            // Flip based on operation type
            let orientedPlane = type == .subtraction ? trimPlane : trimPlane.flipped
            result = result.trimmed(along: orientedPlane.offset(-1e-6))
        }

        // Trim at end vertex
        if isClosed || segmentIndex < segmentCount - 1 {
            let prevVertex = Self.vertex(at: segmentIndex, in: vertices, isClosed: isClosed)
            let currentVertex = Self.vertex(at: segmentIndex + 1, in: vertices, isClosed: isClosed)
            let nextVertex = Self.vertex(at: segmentIndex + 2, in: vertices, isClosed: isClosed)

            let prevDir = (currentVertex - prevVertex).normalized
            let nextDir = (nextVertex - currentVertex).normalized

            // Bisector plane at end vertex
            let bisectorDir = (prevDir + nextDir).normalized
            let trimPlane = Plane(offset: currentVertex, normal: Direction3D(-bisectorDir))

            // Flip based on operation type
            let orientedPlane = type == .subtraction ? trimPlane : trimPlane.flipped
            result = result.trimmed(along: orientedPlane.offset(-1e-6))
        }

        return result
    }
}
