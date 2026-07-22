import Foundation

// MARK: - Matching

internal extension EdgeQuery {
    /// - Parameter maskContainment: One containment lookup per entry in `maskConstraints`, in the
    ///   same order, mapping each candidate vertex position to whether it lies inside that mask.
    ///   Pass an empty array when the query has no mask constraints.
    func matches(_ edge: FoundEdge, maskContainment: [[Vector3D: Bool]] = []) -> Bool {
        if let directionalConstraint, !directionalConstraint.matches(edge) { return false }
        if !spatialConstraints.allSatisfy({ $0.matches(edge) }) { return false }
        if let topologyConstraint, !topologyConstraint.matches(edge) { return false }
        if let convexityConstraint, !convexityConstraint.matches(edge) { return false }
        if let lengthConstraint, !lengthConstraint.matches(edge) { return false }
        for lookup in maskContainment {
            if !edge.vertices.allSatisfy({ lookup[$0] ?? false }) { return false }
        }
        return true
    }
}

// MARK: - Constraint types

internal enum DirectionalConstraint: Sendable, Hashable, Codable {
    case parallel(Direction3D, tolerance: Angle)
    case perpendicular(to: Direction3D, tolerance: Angle)

    // The fraction of an edge's segments that must satisfy the constraint for the edge to match
    private static let requiredMatchingFraction = 0.7

    func matches(_ edge: FoundEdge) -> Bool {
        guard !edge.segments.isEmpty else { return false }
        let matchingCount = edge.segments.count { segment in
            let edgeDirection = segment.direction.unitVector
            switch self {
            case .parallel(let direction, let tolerance):
                return abs(edgeDirection ⋅ direction.unitVector) >= cos(tolerance)
            case .perpendicular(let direction, let tolerance):
                return abs(edgeDirection ⋅ direction.unitVector) <= sin(tolerance)
            }
        }
        return Double(matchingCount) / Double(edge.segments.count) > Self.requiredMatchingFraction
    }
}

internal enum SpatialConstraint: Sendable, Hashable, Codable {
    case withinBox(BoundingBox3D)
    case withinAxisRange(Axis3D, RangeBound)
    case onLine(Line3D, tolerance: Double)
    case onPlane(Plane, tolerance: Double)
    case nearPoint(Vector3D, radius: Double)
    case above(Plane)
    case below(Plane)

    private static let tolerance = 1e-6

    func matches(_ edge: FoundEdge) -> Bool {
        edge.vertices.allSatisfy { vertex in
            switch self {
            case .withinBox(let box):
                box.contains(vertex)
            case .withinAxisRange(let axis, let bound):
                bound.contains(vertex[axis])
            case .onLine(let line, let tolerance):
                line.distance(to: vertex) <= tolerance
            case .onPlane(let plane, let tolerance):
                abs(plane.distance(to: vertex)) <= tolerance
            case .nearPoint(let point, let radius):
                vertex.distance(to: point) <= radius
            case .above(let plane):
                plane.distance(to: vertex) >= -Self.tolerance
            case .below(let plane):
                plane.distance(to: vertex) <= Self.tolerance
            }
        }
    }
}

/// Wraps a mask geometry supplied to `within(mask:)`.
///
/// The geometry itself is excluded from `Hashable`/`Codable`/`Equatable` (see the conformances
/// below) — it can't be compared or serialized in general. Caching still works correctly because
/// `shapingEdges(_:matching:)`, the only cache-key consumer of `EdgeQuery`, separately evaluates
/// each mask into a `GeometryNode` and folds that node into the cache key itself. `EdgeQuery`'s own
/// conformances only need to distinguish "how many masks, in what combination with everything
/// else" — not the mask contents.
internal struct MaskConstraint: Sendable {
    let geometry: any Geometry3D
}

extension MaskConstraint: Hashable {
    static func == (lhs: MaskConstraint, rhs: MaskConstraint) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}

extension MaskConstraint: Codable {
    // Not meaningfully decodable; a decoded query's masks carry no usable geometry. Identity for
    // caching purposes comes from the separately-folded-in mask node, not from round-tripping this.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _ = try container.decode(Bool.self)
        self.geometry = Empty<D3>()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(true)
    }
}

internal enum TopologyConstraint: Sendable, Hashable, Codable {
    case closed
    case open

    func matches(_ edge: FoundEdge) -> Bool {
        switch self {
        case .closed: edge.isClosed
        case .open: !edge.isClosed
        }
    }
}

internal enum ConvexityConstraint: Sendable, Hashable, Codable {
    case convex
    case concave

    func matches(_ edge: FoundEdge) -> Bool {
        switch self {
        case .convex: edge.isConvex
        case .concave: !edge.isConvex
        }
    }
}

internal struct LengthConstraint: Sendable, Hashable, Codable {
    let bound: RangeBound

    func matches(_ edge: FoundEdge) -> Bool {
        bound.contains(edge.length)
    }
}

/// A Hashable & Codable representation of a plain numeric range.
///
/// Stands in for `any WithinRange` so that `EdgeQuery` can be used as a cache key. Used both
/// for a range along a specific axis and for scalar ranges like edge length.
internal struct RangeBound: Hashable, Codable, Sendable {
    let lower: Double?   // nil = -∞
    let upper: Double?   // nil = +∞

    func contains(_ value: Double) -> Bool {
        (lower.map { value >= $0 } ?? true) && (upper.map { value <= $0 } ?? true)
    }

    init(_ range: some WithinRange) {
        switch range {
        case let range as ClosedRange<Double>:         lower = range.lowerBound; upper = range.upperBound
        case let range as Range<Double>:               lower = range.lowerBound; upper = range.upperBound
        case let range as PartialRangeFrom<Double>:    lower = range.lowerBound; upper = nil
        case let range as PartialRangeThrough<Double>: lower = nil;              upper = range.upperBound
        case let range as PartialRangeUpTo<Double>:    lower = nil;              upper = range.upperBound
        default:                                       lower = nil;              upper = nil
        }
    }
}
