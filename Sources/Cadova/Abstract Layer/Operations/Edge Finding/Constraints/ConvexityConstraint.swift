import Foundation

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
