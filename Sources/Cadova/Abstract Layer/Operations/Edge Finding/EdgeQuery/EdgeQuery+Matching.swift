import Foundation

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
