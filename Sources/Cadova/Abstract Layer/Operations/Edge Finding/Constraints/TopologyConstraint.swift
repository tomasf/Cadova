import Foundation

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
