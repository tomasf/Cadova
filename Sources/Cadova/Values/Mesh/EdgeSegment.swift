import Foundation

/// A single segment of an edge in a mesh, identified by two vertex indices.
///
/// Edge segments are the low-level mesh primitives that make up edges.
/// They are stored in a canonical form where the smaller vertex index comes first,
/// ensuring that the same segment shared by multiple triangles has a consistent representation.
///
/// For user-facing edge operations, see ``Edge`` which represents a complete edge
/// feature (potentially composed of multiple connected segments).
///
public struct EdgeSegment: Hashable, Sendable {
    /// The index of the first vertex (always the smaller index).
    public let v0: Int

    /// The index of the second vertex (always the larger index).
    public let v1: Int

    /// Creates an edge segment from two vertex indices.
    ///
    /// The indices are automatically reordered so that v0 < v1.
    ///
    public init(_ a: Int, _ b: Int) {
        if a < b {
            self.v0 = a
            self.v1 = b
        } else {
            self.v0 = b
            self.v1 = a
        }
    }
}

public extension EdgeSegment {
    /// Returns the vertex positions for this segment.
    func vertices(in mesh: MeshTopology) -> (Vector3D, Vector3D) {
        (mesh.vertices[v0], mesh.vertices[v1])
    }

    /// Returns the segment as a 3D vector from v0 to v1.
    func vector(in mesh: MeshTopology) -> Vector3D {
        let (p0, p1) = vertices(in: mesh)
        return p1 - p0
    }

    /// Returns the length of this segment.
    func length(in mesh: MeshTopology) -> Double {
        vector(in: mesh).magnitude
    }

    /// Returns the midpoint of this segment.
    func midpoint(in mesh: MeshTopology) -> Vector3D {
        let (p0, p1) = vertices(in: mesh)
        return (p0 + p1) / 2
    }
}
