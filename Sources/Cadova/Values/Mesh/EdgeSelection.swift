import Foundation

/// A selection of mesh edges based on various filtering criteria.
///
/// `EdgeSelection` provides a fluent API for finding and filtering edges in a mesh.
/// Start with a mesh topology, apply filters, and extract the resulting edges or chains.
///
/// ```swift
/// let topology = MeshTopology(manifold: myManifold)
/// let sharpEdges = EdgeSelection(topology)
///     .sharp(threshold: 160°)
///     .within(boundingBox)
///     .edges
/// ```
///
public struct EdgeSelection: Sendable {
    /// The mesh topology being queried.
    public let topology: MeshTopology

    /// The currently selected edges.
    public let edges: [MeshEdge]

    /// Creates an edge selection containing all edges in the mesh.
    public init(_ topology: MeshTopology) {
        self.topology = topology
        self.edges = topology.edges
    }

    /// Creates an edge selection with a specific set of edges.
    public init(_ topology: MeshTopology, edges: [MeshEdge]) {
        self.topology = topology
        self.edges = edges
    }
}

// MARK: - Sharpness Filtering

public extension EdgeSelection {
    /// Filters to edges that are "sharp" based on dihedral angle.
    ///
    /// - Parameter threshold: The maximum dihedral angle for an edge to be considered sharp.
    ///   Smaller values are more selective. Default is 170° (nearly all non-flat edges).
    /// - Returns: A new selection containing only sharp edges.
    ///
    func sharp(threshold: Angle = 170°) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter {
            topology.isSharpEdge($0, threshold: threshold)
        })
    }

    /// Filters to edges within a specific dihedral angle range.
    ///
    /// - Parameters:
    ///   - range: The range of dihedral angles to include.
    /// - Returns: A new selection containing only edges within the angle range.
    ///
    func withDihedralAngle(in range: ClosedRange<Angle>) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { edge in
            guard let angle = topology.dihedralAngle(for: edge) else { return false }
            return range.contains(angle)
        })
    }
}

// MARK: - Spatial Filtering

public extension EdgeSelection {
    /// Filters to edges that intersect or are contained within a bounding box.
    ///
    /// An edge is included if any part of it is within the bounding box.
    ///
    func within(_ box: BoundingBox3D) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { edge in
            let (p0, p1) = edge.vertices(in: topology)
            // Check if either endpoint is in the box, or if the edge crosses the box
            return box.contains(p0) || box.contains(p1) || edgeIntersectsBox(p0, p1, box)
        })
    }

    /// Filters to edges whose midpoint is within a distance of a point.
    ///
    func nearPoint(_ point: Vector3D, distance: Double) -> EdgeSelection {
        let distanceSquared = distance * distance
        return EdgeSelection(topology, edges: edges.filter { edge in
            let midpoint = edge.midpoint(in: topology)
            let diff = midpoint - point
            return diff.squaredEuclideanNorm <= distanceSquared
        })
    }

    /// Filters to edges whose midpoint is within a distance of an axis.
    ///
    func nearAxis(_ axis: Axis3D, distance: Double, origin: Vector3D = .zero) -> EdgeSelection {
        let distanceSquared = distance * distance
        let axisVector = axis.direction(.positive).unitVector
        return EdgeSelection(topology, edges: edges.filter { edge in
            let midpoint = edge.midpoint(in: topology)
            let offset = midpoint - origin
            let alongAxis = offset[axis]
            let perpendicular = offset - axisVector * alongAxis
            return perpendicular.squaredEuclideanNorm <= distanceSquared
        })
    }

    private func edgeIntersectsBox(_ p0: Vector3D, _ p1: Vector3D, _ box: BoundingBox3D) -> Bool {
        // Simple line-box intersection test using parametric line equation
        let direction = p1 - p0
        var tMin = 0.0
        var tMax = 1.0

        for axis in Axis3D.allCases {
            let origin = p0[axis]
            let dir = direction[axis]
            let boxMin = box.minimum[axis]
            let boxMax = box.maximum[axis]

            if Swift.abs(dir) < 1e-10 {
                // Line is parallel to this axis
                if origin < boxMin || origin > boxMax {
                    return false
                }
            } else {
                let t1 = (boxMin - origin) / dir
                let t2 = (boxMax - origin) / dir
                let tNear = min(t1, t2)
                let tFar = max(t1, t2)
                tMin = max(tMin, tNear)
                tMax = min(tMax, tFar)
                if tMin > tMax {
                    return false
                }
            }
        }

        return true
    }
}

// MARK: - Direction Filtering

public extension EdgeSelection {
    /// Filters to edges that are approximately aligned with a direction.
    ///
    /// - Parameters:
    ///   - direction: The direction to compare against.
    ///   - tolerance: The maximum angle deviation from the direction. Default is 15°.
    /// - Returns: A new selection containing only edges aligned with the direction.
    ///
    func aligned(with direction: Vector3D, tolerance: Angle = 15°) -> EdgeSelection {
        let normalizedDir = direction.normalized
        let cosThreshold: Double = cos(tolerance)

        return EdgeSelection(topology, edges: edges.filter { edge in
            let edgeDir = edge.vector(in: topology).normalized
            let dot = Swift.abs(edgeDir ⋅ normalizedDir) // Use abs because edge direction is arbitrary
            return dot >= cosThreshold
        })
    }

    /// Filters to edges that are approximately perpendicular to a direction.
    ///
    /// - Parameters:
    ///   - direction: The direction to compare against.
    ///   - tolerance: The maximum angle deviation from perpendicular. Default is 15°.
    /// - Returns: A new selection containing only edges perpendicular to the direction.
    ///
    func perpendicular(to direction: Vector3D, tolerance: Angle = 15°) -> EdgeSelection {
        let normalizedDir = direction.normalized
        let cosThreshold: Double = cos(90° - tolerance)

        return EdgeSelection(topology, edges: edges.filter { edge in
            let edgeDir = edge.vector(in: topology).normalized
            let dot = Swift.abs(edgeDir ⋅ normalizedDir)
            return dot <= cosThreshold
        })
    }

    /// Filters to edges aligned with a specific axis.
    func aligned(with axis: Axis3D, tolerance: Angle = 15°) -> EdgeSelection {
        aligned(with: axis.direction(.positive).unitVector, tolerance: tolerance)
    }

    /// Filters to edges perpendicular to a specific axis (i.e., lying in the plane normal to that axis).
    func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeSelection {
        perpendicular(to: axis.direction(.positive).unitVector, tolerance: tolerance)
    }
}

// MARK: - Length Filtering

public extension EdgeSelection {
    /// Filters to edges within a length range.
    func withLength(in range: ClosedRange<Double>) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { edge in
            let length = edge.length(in: topology)
            return range.contains(length)
        })
    }

    /// Filters to edges with at least the specified minimum length.
    func withMinimumLength(_ minLength: Double) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { edge in
            edge.length(in: topology) >= minLength
        })
    }

    /// Filters to edges with at most the specified maximum length.
    func withMaximumLength(_ maxLength: Double) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { edge in
            edge.length(in: topology) <= maxLength
        })
    }
}

// MARK: - Chaining

public extension EdgeSelection {
    /// Groups the selected edges into connected chains.
    ///
    /// - Parameter continuityThreshold: The maximum angle between connected edges
    ///   for them to be considered part of the same chain. Default is 30°.
    /// - Returns: An array of edge chains.
    ///
    func chained(continuityThreshold: Angle = 30°) -> [EdgeChain] {
        topology.chainEdges(edges, continuityThreshold: continuityThreshold)
    }
}

// MARK: - Set Operations

public extension EdgeSelection {
    /// Returns a selection containing edges that are in both this selection and another.
    func intersection(_ other: EdgeSelection) -> EdgeSelection {
        let otherSet = Set(other.edges)
        return EdgeSelection(topology, edges: edges.filter { otherSet.contains($0) })
    }

    /// Returns a selection containing edges from this selection that are not in another.
    func subtracting(_ other: EdgeSelection) -> EdgeSelection {
        let otherSet = Set(other.edges)
        return EdgeSelection(topology, edges: edges.filter { !otherSet.contains($0) })
    }

    /// Returns a selection containing edges from either this selection or another.
    func union(_ other: EdgeSelection) -> EdgeSelection {
        let combined = Set(edges).union(other.edges)
        return EdgeSelection(topology, edges: Array(combined))
    }
}

// MARK: - Utilities

public extension EdgeSelection {
    /// The number of selected edges.
    var count: Int { edges.count }

    /// Whether the selection is empty.
    var isEmpty: Bool { edges.isEmpty }

    /// Returns a selection with edges filtered by a custom predicate.
    func filter(_ predicate: (MeshEdge, MeshTopology) -> Bool) -> EdgeSelection {
        EdgeSelection(topology, edges: edges.filter { predicate($0, topology) })
    }
}
