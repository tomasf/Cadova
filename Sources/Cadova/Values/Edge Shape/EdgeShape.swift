import Foundation

/// A symmetric cross-section applied along the edges of a 3D model, such as a chamfer or fillet.
///
/// An `EdgeShape` is symmetric across the plane bisecting the edge's two faces, which makes it
/// applicable to edges of any orientation and any dihedral angle. Convex (outside) edges have
/// the shape cut away; concave (inside corner) edges have it added as material.
///
/// For cases where you need an asymmetric cross-section anchored to a fixed horizontal/vertical
/// frame — such as extrusion caps or print-orientation-aware profiles — use
/// ``EdgeProfile`` instead.
///
/// Use the built-in `chamfer(depth:)` and `fillet(radius:)` shapes, or define your own
/// cross-section curve with `custom(name:parameters:curve:)`.
///
/// Apply an edge shape with `shapingEdges(_:matching:)`:
///
/// ```swift
/// Box(10).shapingEdges(.fillet(radius: 2), matching: .all)
/// ```
///
public struct EdgeShape: Sendable {
    internal enum Kind: Hashable, Codable, Sendable {
        case chamfer (depth: Double)
        case chamferByWidth (width: Double)
        case fillet (radius: Double)
        case filletByDepth (depth: Double)
        case custom (name: String, parameters: [AnyCacheKey])
    }

    internal let kind: Kind

    // Not part of the shape's identity; see the custom(name:parameters:curve:) contract.
    internal let customCurve: (@Sendable (EdgeShapeParameters) -> [Vector2D])?

    internal init(kind: Kind, customCurve: (@Sendable (EdgeShapeParameters) -> [Vector2D])? = nil) {
        self.kind = kind
        self.customCurve = customCurve
    }
}

extension EdgeShape: Hashable {
    public static func == (lhs: EdgeShape, rhs: EdgeShape) -> Bool {
        lhs.kind == rhs.kind
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
    }
}

extension EdgeShape: Codable {
    public init(from decoder: any Decoder) throws {
        // A decoded custom shape has no curve closure and cannot generate geometry;
        // decoded shapes are only used for cache identity.
        self.init(kind: try Kind(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        try kind.encode(to: encoder)
    }
}

/// The context in which an `EdgeShape` cross-section curve is generated.
///
/// The cross-section is defined in a normalized 2D frame local to a point on the edge:
/// - The origin is on the edge itself.
/// - The positive X axis points into the wedge being modified — into the material for convex
///   edges, and into the empty inside corner for concave edges.
/// - The two faces extend from the origin at angles of ±`wedgeAngle`/2 from the X axis.
///
public struct EdgeShapeParameters: Sendable {
    /// The angle of the wedge between the edge's two faces, always less than 180°.
    ///
    /// For convex edges, this is the dihedral angle of the edge; a square box edge measures 90°.
    /// For concave edges, it's the angle of the empty wedge; a square inside corner also measures 90°.
    public let wedgeAngle: Angle

    /// Whether the edge is convex (an outside edge, where the shape is cut away)
    /// as opposed to concave (an inside corner, where the shape is added as material).
    public let isConvex: Bool

    /// The number of curve segments to aim for. Curves must contain the same number of
    /// points whenever the segment count is the same.
    public let segmentCount: Int

    internal init(wedgeAngle: Angle, isConvex: Bool, segmentCount: Int) {
        self.wedgeAngle = wedgeAngle
        self.isConvex = isConvex
        self.segmentCount = segmentCount
    }
}
