import Foundation

public extension EdgeQuery {
    private func with(topology: TopologyConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topology,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    private func with(convexity: ConvexityConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexity,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    /// A query that only accepts closed (loop) edges.
    var closed: EdgeQuery {
        with(topology: .closed)
    }

    /// A query that only accepts open (non-loop) edges.
    var open: EdgeQuery {
        with(topology: .open)
    }

    /// A query that only accepts convex (outside) edges.
    var convex: EdgeQuery {
        with(convexity: .convex)
    }

    /// A query that only accepts concave (inside corner) edges.
    var concave: EdgeQuery {
        with(convexity: .concave)
    }
}
