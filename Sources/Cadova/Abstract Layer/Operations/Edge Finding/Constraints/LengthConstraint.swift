import Foundation

internal struct LengthConstraint: Sendable, Hashable, Codable {
    let bound: RangeBound

    func matches(_ edge: FoundEdge) -> Bool {
        bound.contains(edge.length)
    }
}
