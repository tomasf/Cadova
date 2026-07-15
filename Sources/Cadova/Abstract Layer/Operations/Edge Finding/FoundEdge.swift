import Foundation

/// A single straight segment of a found edge — one edge of the model's evaluated triangle mesh —
/// with its two adjacent face normals.
///
/// Edge segments have consistent orientation: when traveled from `start` to `end`,
/// `leftFaceNormal` is the outward normal of the face on the left and `rightFaceNormal`
/// is the outward normal of the face on the right.
///
public struct EdgeSegment: Sendable, Hashable, Codable {
    /// The starting point of this segment.
    public let start: Vector3D
    /// The ending point of this segment.
    public let end: Vector3D
    /// Outward normal of the face on the left when traveling from start to end.
    public let leftFaceNormal: Direction3D
    /// Outward normal of the face on the right when traveling from start to end.
    public let rightFaceNormal: Direction3D

    /// The direction of travel from `start` to `end`.
    public var direction: Direction3D {
        Direction3D(end - start)
    }

    /// The length of this segment.
    public var length: Double {
        (end - start).magnitude
    }

    /// The midpoint of this segment.
    public var midpoint: Vector3D {
        (start + end) / 2
    }

    /// Whether the edge is convex (material on the inside of the wedge, like the outside edges of a box)
    /// as opposed to concave (an inside corner, like where a wall meets a floor).
    public var isConvex: Bool {
        ((leftFaceNormal.unitVector × rightFaceNormal.unitVector) ⋅ direction.unitVector) > 0
    }

    /// The interior dihedral angle between the two adjacent faces, measured through the material.
    ///
    /// A square outside edge measures 90°; flat is 180°; a square inside corner measures 270°.
    public var dihedralAngle: Angle {
        let deviation: Angle = acos((leftFaceNormal.unitVector ⋅ rightFaceNormal.unitVector).clamped(to: -1.0...1.0))
        return isConvex ? 180° - deviation : 180° + deviation
    }

    /// The angle of the wedge being modified: the dihedral angle for convex edges, and the
    /// angle of the empty inside corner for concave ones. Always less than 180°.
    internal var wedgeAngle: Angle {
        isConvex ? dihedralAngle : 360° - dihedralAngle
    }
}

/// A chain of connected edge segments representing a sharp feature of a model's evaluated mesh.
///
/// Edges are found by comparing the dihedral angle between adjacent mesh faces against a
/// sharpness threshold (30° deviation from flat, by default). Smooth regions — the curved
/// surface of a sphere or cylinder, for instance — contribute no edges unless their
/// segmentation is coarse enough to introduce visible faceting. Consecutive sharp segments are
/// chained together as long as they don't turn too sharply from one to the next, so a single
/// `FoundEdge` can span many mesh vertices; see `EdgeQuery` for how the sharpness and turn
/// thresholds are controlled.
///
/// A `FoundEdge` is either open (a polyline from one endpoint to another) or closed (a loop).
/// Use `readingEdges(matching:)` to find edges in a model.
///
public struct FoundEdge: Sendable, Hashable, Codable {
    /// The individual straight segments making up this edge, in order.
    public let segments: [EdgeSegment]

    internal init(segments: [EdgeSegment]) {
        self.segments = segments
    }

    /// `true` if the edge forms a closed loop.
    public var isClosed: Bool {
        guard let first = segments.first, let last = segments.last, segments.count > 1 else { return false }
        return first.start.distance(to: last.end) < 1e-9
    }

    /// Whether the edge is convex (an outside edge) as opposed to concave (an inside corner).
    ///
    /// All segments of a found edge share the same convexity; edges are split where convexity changes.
    public var isConvex: Bool {
        segments.first?.isConvex ?? true
    }

    /// All vertices along the edge, in order. For closed edges, the first vertex is not repeated at the end.
    public var vertices: [Vector3D] {
        guard let first = segments.first else { return [] }
        var result = [first.start]
        for segment in isClosed ? segments.dropLast() : segments[...] {
            result.append(segment.end)
        }
        return result
    }

    /// The axis-aligned bounding box enclosing this edge.
    public var boundingBox: BoundingBox3D {
        BoundingBox3D(vertices)
    }

    /// The total length of this edge (the sum of all segment lengths).
    public var length: Double {
        segments.reduce(0) { $0 + $1.length }
    }

    /// The average dihedral angle across all segments, weighted by segment length.
    public var averageDihedralAngle: Angle {
        let totalLength = length
        guard totalLength > 0 else { return 180° }
        let weightedSum = segments.reduce(0.0) { $0 + $1.dihedralAngle.degrees * $1.length }
        return Angle(degrees: weightedSum / totalLength)
    }
}
