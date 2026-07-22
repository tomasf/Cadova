import Foundation

/// A composable set of criteria for selecting which edges of a model to act on.
///
/// Every modifier is also available as a static starting point, so a query can begin directly
/// with whichever criterion matters to you:
///
/// ```swift
/// .along(.z)                            // vertical edges only
/// .within(z: 4.9...).convex             // convex edges near the top
/// .withSharpness(80°...100°).convex     // near-square convex edges only
/// ```
///
/// Use `.all` when you don't need any filtering beyond the default sharpness (30° deviation
/// from flat — this is also the minimum used when starting from any other modifier). Edges
/// continue through gentle direction changes but split at corners turning more than 45°;
/// adjust with `withMaxTurn(_:)`.
///
/// Pass the query to `readingEdges(matching:)` or `shapingEdges(_:matching:)`.
///
public struct EdgeQuery: Sendable, Hashable, Codable {
    /// Minimum angular deviation from flat (180°) required for an edge to be considered sharp.
    let minimumSharpness: Angle

    /// Maximum angular deviation from flat (180°) allowed, if narrowing away from very sharp
    /// (knife-edge) features. `nil` means unbounded.
    let maximumSharpness: Angle?

    /// The largest change of direction an edge can make at a vertex and still continue as the
    /// same edge. Turns beyond this split the chain into separate edges.
    let maximumTurnAngle: Angle

    let directionalConstraint: DirectionalConstraint?
    let spatialConstraints: [SpatialConstraint]
    let topologyConstraint: TopologyConstraint?
    let convexityConstraint: ConvexityConstraint?
    let lengthConstraint: LengthConstraint?
    let maskConstraints: [MaskConstraint]

    internal init(
        minimumSharpness: Angle = 30°,
        maximumSharpness: Angle? = nil,
        maximumTurnAngle: Angle = 45°,
        directionalConstraint: DirectionalConstraint? = nil,
        spatialConstraints: [SpatialConstraint] = [],
        topologyConstraint: TopologyConstraint? = nil,
        convexityConstraint: ConvexityConstraint? = nil,
        lengthConstraint: LengthConstraint? = nil,
        maskConstraints: [MaskConstraint] = []
    ) {
        self.minimumSharpness = minimumSharpness
        self.maximumSharpness = maximumSharpness
        self.maximumTurnAngle = maximumTurnAngle
        self.directionalConstraint = directionalConstraint
        self.spatialConstraints = spatialConstraints
        self.topologyConstraint = topologyConstraint
        self.convexityConstraint = convexityConstraint
        self.lengthConstraint = lengthConstraint
        self.maskConstraints = maskConstraints
    }

    /// Selects all edges, using the default sharpness (30° deviation from flat).
    public static let all = EdgeQuery()
}
