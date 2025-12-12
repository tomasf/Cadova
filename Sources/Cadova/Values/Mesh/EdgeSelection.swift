import Foundation

/// A selection of edges based on various filtering criteria.
///
/// `EdgeSelection` provides a fluent API for finding and filtering edges in a mesh.
/// Start with a mesh topology, apply filters, and extract the resulting edges.
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

    /// The currently selected edge segments.
    public let segments: [EdgeSegment]

    /// Creates an edge selection containing all edges in the mesh.
    public init(_ topology: MeshTopology) {
        self.topology = topology
        self.segments = topology.allSegments
    }

    /// Creates an edge selection with a specific set of segments.
    public init(_ topology: MeshTopology, segments: [EdgeSegment]) {
        self.topology = topology
        self.segments = segments
    }

    /// The selected edges, grouped from connected segments.
    ///
    /// Adjacent segments that form a continuous path are combined into single edges.
    /// Use ``edges(continuityThreshold:)`` to control how segments are grouped.
    ///
    public var edges: [Edge] {
        edges()
    }

    /// Returns the selected edges with a custom continuity threshold.
    ///
    /// - Parameter continuityThreshold: The maximum angle between connected segments
    ///   for them to be considered part of the same edge. Default is 30°.
    /// - Returns: An array of edges.
    ///
    public func edges(continuityThreshold: Angle = 30°) -> [Edge] {
        topology.buildEdges(from: segments, continuityThreshold: continuityThreshold)
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
        EdgeSelection(topology, segments: segments.filter {
            topology.isSharpSegment($0, threshold: threshold)
        })
    }

    /// Filters to edges within a specific dihedral angle range.
    ///
    /// - Parameters:
    ///   - range: The range of dihedral angles to include.
    /// - Returns: A new selection containing only edges within the angle range.
    ///
    func withDihedralAngle(in range: ClosedRange<Angle>) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { segment in
            guard let angle = topology.dihedralAngle(for: segment) else { return false }
            return range.contains(angle)
        })
    }
}

// MARK: - Spatial Filtering

public extension EdgeSelection {
    /// Filters to edges that intersect or are contained within the specified ranges.
    ///
    /// An edge is included if any part of it is within all specified ranges.
    /// Axes that are `nil` are unbounded. You can use any `Range` expression,
    /// including open, closed, partial, and infinite ranges.
    ///
    /// ```swift
    /// edges.within(z: 0...)  // Edges in upper half
    /// edges.within(x: -5...5, y: -5...5)  // Edges near the Z axis
    /// ```
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, no filtering on this axis.
    ///   - y: Optional range along the y-axis. If `nil`, no filtering on this axis.
    ///   - z: Optional range along the z-axis. If `nil`, no filtering on this axis.
    /// - Returns: A new selection containing only edges within the specified ranges.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> EdgeSelection {
        // Convert ranges to a bounding box for the intersection test
        let largeValue = 1e10
        let box = BoundingBox3D(
            minimum: Vector3D(
                x: x?.min ?? -largeValue,
                y: y?.min ?? -largeValue,
                z: z?.min ?? -largeValue
            ),
            maximum: Vector3D(
                x: x?.max ?? largeValue,
                y: y?.max ?? largeValue,
                z: z?.max ?? largeValue
            )
        )
        return within(box)
    }

    /// Filters to edges that intersect or are contained within a bounding box.
    ///
    /// An edge is included if any part of it is within the bounding box.
    ///
    func within(_ box: BoundingBox3D) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { segment in
            let (p0, p1) = segment.vertices(in: topology)
            // Check if either endpoint is in the box, or if the segment crosses the box
            return box.contains(p0) || box.contains(p1) || segmentIntersectsBox(p0, p1, box)
        })
    }

    /// Filters to edges whose midpoint is within a distance of a point.
    ///
    func nearPoint(_ point: Vector3D, distance: Double) -> EdgeSelection {
        let distanceSquared = distance * distance
        return EdgeSelection(topology, segments: segments.filter { segment in
            let midpoint = segment.midpoint(in: topology)
            let diff = midpoint - point
            return diff.squaredEuclideanNorm <= distanceSquared
        })
    }

    /// Filters to edges whose midpoint is within a distance of an axis.
    ///
    func nearAxis(_ axis: Axis3D, distance: Double, origin: Vector3D = .zero) -> EdgeSelection {
        let distanceSquared = distance * distance
        let axisVector = axis.direction(.positive).unitVector
        return EdgeSelection(topology, segments: segments.filter { segment in
            let midpoint = segment.midpoint(in: topology)
            let offset = midpoint - origin
            let alongAxis = offset[axis]
            let perpendicular = offset - axisVector * alongAxis
            return perpendicular.squaredEuclideanNorm <= distanceSquared
        })
    }

    private func segmentIntersectsBox(_ p0: Vector3D, _ p1: Vector3D, _ box: BoundingBox3D) -> Bool {
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
    func aligned(with direction: Direction3D, tolerance: Angle = 15°) -> EdgeSelection {
        let dirVector = direction.unitVector
        let cosThreshold: Double = cos(tolerance)

        return EdgeSelection(topology, segments: segments.filter { segment in
            let segmentDir = segment.vector(in: topology).normalized
            let dot = Swift.abs(segmentDir ⋅ dirVector) // Use abs because segment direction is arbitrary
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
    func perpendicular(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeSelection {
        let dirVector = direction.unitVector
        let cosThreshold: Double = cos(90° - tolerance)

        return EdgeSelection(topology, segments: segments.filter { segment in
            let segmentDir = segment.vector(in: topology).normalized
            let dot = Swift.abs(segmentDir ⋅ dirVector)
            return dot <= cosThreshold
        })
    }

    /// Filters to edges aligned with a specific axis.
    func aligned(with axis: Axis3D, tolerance: Angle = 15°) -> EdgeSelection {
        aligned(with: axis.direction(.positive), tolerance: tolerance)
    }

    /// Filters to edges perpendicular to a specific axis (i.e., lying in the plane normal to that axis).
    func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeSelection {
        perpendicular(to: axis.direction(.positive), tolerance: tolerance)
    }

    /// Filters to edges that lie within a plane.
    ///
    /// An edge lies in the plane if it is parallel to the plane (perpendicular to the normal)
    /// and both endpoints are on the plane within the specified tolerance.
    ///
    /// ```swift
    /// edges.in(plane: .z(0))  // Edges lying in the XY plane
    /// edges.in(plane: Plane(z: 5), tolerance: 0.1)  // Edges at height z=5
    /// ```
    ///
    /// - Parameters:
    ///   - plane: The plane to test against.
    ///   - tolerance: The maximum distance from the plane for endpoints,
    ///     and the maximum angle deviation from parallel. Default is 0.01 for distance.
    /// - Returns: A new selection containing only edges lying in the plane.
    ///
    func `in`(plane: Plane, tolerance: Double = 0.01) -> EdgeSelection {
        let normalVector = plane.normal.unitVector
        let cosThreshold: Double = cos(90° - 1°)  // Segment must be nearly perpendicular to normal

        return EdgeSelection(topology, segments: segments.filter { segment in
            let (p0, p1) = segment.vertices(in: topology)

            // Check both endpoints are on the plane
            let dist0 = Swift.abs(plane.distance(to: p0))
            let dist1 = Swift.abs(plane.distance(to: p1))
            guard dist0 <= tolerance && dist1 <= tolerance else {
                return false
            }

            // Check segment direction is perpendicular to plane normal (parallel to plane)
            let segmentDir = segment.vector(in: topology).normalized
            let dot = Swift.abs(segmentDir ⋅ normalVector)
            return dot <= cosThreshold
        })
    }
}

// MARK: - Length Filtering

public extension EdgeSelection {
    /// Filters to edges within a length range.
    func withLength(in range: ClosedRange<Double>) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { segment in
            let length = segment.length(in: topology)
            return range.contains(length)
        })
    }

    /// Filters to edges with at least the specified minimum length.
    func withMinimumLength(_ minLength: Double) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { segment in
            segment.length(in: topology) >= minLength
        })
    }

    /// Filters to edges with at most the specified maximum length.
    func withMaximumLength(_ maxLength: Double) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { segment in
            segment.length(in: topology) <= maxLength
        })
    }
}

// MARK: - Set Operations

public extension EdgeSelection {
    /// Returns a selection containing edges that are in both this selection and another.
    func intersection(_ other: EdgeSelection) -> EdgeSelection {
        let otherSet = Set(other.segments)
        return EdgeSelection(topology, segments: segments.filter { otherSet.contains($0) })
    }

    /// Returns a selection containing edges from this selection that are not in another.
    func subtracting(_ other: EdgeSelection) -> EdgeSelection {
        let otherSet = Set(other.segments)
        return EdgeSelection(topology, segments: segments.filter { !otherSet.contains($0) })
    }

    /// Returns a selection containing edges from either this selection or another.
    func union(_ other: EdgeSelection) -> EdgeSelection {
        let combined = Set(segments).union(other.segments)
        return EdgeSelection(topology, segments: Array(combined))
    }
}

// MARK: - Utilities

public extension EdgeSelection {
    /// The number of selected edge segments.
    var segmentCount: Int { segments.count }

    /// Whether the selection is empty.
    var isEmpty: Bool { segments.isEmpty }

    /// Returns a selection with segments filtered by a custom predicate.
    func filter(_ predicate: (EdgeSegment, MeshTopology) -> Bool) -> EdgeSelection {
        EdgeSelection(topology, segments: segments.filter { predicate($0, topology) })
    }
}
