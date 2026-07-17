import Foundation

public extension Loft {
    /// Specifies how a loft section transitions from the previous section.
    ///
    /// This enum provides control over the geometric operation used to connect two adjacent
    /// sections in a loft. By default, sections are connected via shape interpolation, but you
    /// can also specify a convex hull connection for certain segments.
    ///
    enum Transition: Hashable, Sendable, Codable {
        /// Interpolates between the previous section's shape and this section's shape using
        /// the specified shaping function.
        ///
        /// The shaping function controls the rate of interpolation. For example, `.linear`
        /// produces evenly spaced intermediate cross-sections, while `.easeIn` or `.easeOut`
        /// can create more organic transitions.
        ///
        case interpolated(ShapingFunction)

        /// Connects the previous section to this section using a 3D convex hull.
        ///
        /// Instead of interpolating intermediate cross-sections, this creates the smallest
        /// convex shape that contains both sections. This is useful for creating tapered or
        /// faceted transitions between shapes, especially when both shapes are convex.
        ///
        /// - Note: The convex hull operation ignores holes in the shapes. The result will
        ///   be a solid convex polyhedron connecting the outer boundaries of both sections.
        ///
        case convexHull
    }
}
