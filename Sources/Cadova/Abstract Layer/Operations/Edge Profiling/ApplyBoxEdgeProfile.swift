import Foundation

public extension Geometry3D {
    /// Applies an edge profile to a specified edge of a box-shaped geometry, using the bounding box as a positional
    /// reference.
    ///
    /// This method uses the geometry’s bounding box to guide the placement and orientation of the edge profile (e.g.,
    /// chamfer or fillet) on the specified edge. Note that for asymmetric profiles, the orientation on vertical
    /// (Z-axis) edges is undefined.
    ///
    /// - Parameters:
    ///   - edgeProfile: The profile to apply to the specified edge, defined as an `EdgeProfile`.
    ///   - edge: The edge of the box where the profile is applied, specified as `Box.Edge`.
    /// - Returns: A new `Geometry3D` object with the edge modified by the specified profile.
    ///
    /// This method is designed for box-like geometries where adding a profile to a specific edge is desired, with the
    /// bounding box serving as a positional reference.
    ///
    func applyingEdgeProfile(_ edgeProfile: EdgeProfile, to edge: Box.Edge) -> any Geometry3D {
        measuringBounds { _, bounds in
            let epsilon = 1e-6

            edgeProfile.readingNegativeShape { negativeShape, profileSize in
                self.subtracting(negativeShape
                    .translated(x: epsilon, y: epsilon)
                    .flipped(along: .xy)
                    .rotated(edge.profileRotation)
                    .extruded(height: bounds.size[edge.axis] + 2 * epsilon)
                    .translated(z: -epsilon)
                    .rotated(from: .up, to: edge.axis.direction(.positive))
                    .flipped(along: edge.flippedProfileAxes)
                    .translated(edge.unitOffset * bounds.size)
                    .translated(bounds.minimum)
                )
            }
        }
    }

    /// Applies an edge profile to multiple edges of a box-shaped geometry, using the bounding box as a positional
    /// reference.
    ///
    /// This method uses the geometry’s bounding box to guide the placement and orientation of the edge profile (e.g.,
    /// chamfer or fillet) on the specified edges. Note that for asymmetric profiles, the orientation on vertical
    /// (Z-axis) edges is undefined.
    ///
    /// - Parameters:
    ///   - edgeProfile: The profile to apply to each specified edge, defined as an `EdgeProfile`.
    ///   - edges: The set of edges of the box where the profile is applied, specified as `Box.Edges`.
    ///
    /// - Returns: A new `Geometry3D` object with the specified edges modified by the profile.
    ///
    /// This method is designed for box-like geometries where adding a profile to multiple edges is desired, with the
    /// bounding box serving as a positional reference.
    ///
    func applyingEdgeProfile(_ edgeProfile: EdgeProfile, to edges: Box.Edges) -> any Geometry3D {
        edges.reduce(self) { $0.applyingEdgeProfile(edgeProfile, to: $1) }
    }
}

fileprivate extension Box.Edge {
    var profileRotation: Angle {
        axis == .y ? 0° : -90°
    }

    var flippedProfileAxes: Axes3D {
        .init(x: x == .max, y: y == .min, z: z == .min) - axis
    }
}
