import Foundation

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
