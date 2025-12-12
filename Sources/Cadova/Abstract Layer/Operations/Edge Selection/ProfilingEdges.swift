import Foundation
import Manifold3D

public extension Geometry3D {
    /// Cuts an edge profile along the sharp edges of this geometry.
    ///
    /// This method identifies sharp edges in the mesh and applies the specified
    /// edge profile along each edge.
    ///
    /// ```swift
    /// Box(10)
    ///     .cuttingEdgeProfile(.chamfer(depth: 1), sharpnessThreshold: 100°)
    /// ```
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply (e.g., chamfer or fillet).
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 100° (edges with angles less than this are profiled).
    ///   - continuityThreshold: The maximum angle between segments for them to form a single edge.
    ///     Default is 30°.
    /// - Returns: A new geometry with the profile cut along sharp edges.
    ///
    func cuttingEdgeProfile(
        _ profile: EdgeProfile,
        sharpnessThreshold: Angle = 100°,
        continuityThreshold: Angle = 30°
    ) -> any Geometry3D {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let edges = EdgeSelection(topology)
                .sharp(threshold: sharpnessThreshold)
                .edges(continuityThreshold: continuityThreshold)

            let profileGeometry = edges.mapUnion { edge in
                edge.profileGeometry(profile, in: topology, type: .subtraction)
            }

            self.subtracting { profileGeometry }
        }
    }

    /// Forms an edge profile along the sharp edges of this geometry.
    ///
    /// This method identifies sharp edges in the mesh and adds the specified
    /// edge profile along each edge.
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply (e.g., chamfer or fillet).
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 100° (edges with angles less than this are profiled).
    ///   - continuityThreshold: The maximum angle between segments for them to form a single edge.
    ///     Default is 30°.
    /// - Returns: A new geometry with the profile formed along sharp edges.
    ///
    func formingEdgeProfile(
        _ profile: EdgeProfile,
        sharpnessThreshold: Angle = 100°,
        continuityThreshold: Angle = 30°
    ) -> any Geometry3D {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let edges = EdgeSelection(topology)
                .sharp(threshold: sharpnessThreshold)
                .edges(continuityThreshold: continuityThreshold)

            let profileGeometry = edges.mapUnion { edge in
                edge.profileGeometry(profile, in: topology, type: .addition)
            }

            self.adding { profileGeometry }
        }
    }

    /// Cuts an edge profile along specific edges.
    ///
    /// Use this method when you need fine-grained control over which edges are profiled.
    /// First use `readingEdges` to select and filter edges, then apply the profile.
    ///
    /// ```swift
    /// myGeometry.readingEdges { geometry, selection in
    ///     let verticalEdges = selection
    ///         .sharp(threshold: 100°)
    ///         .aligned(with: .z)
    ///         .edges
    ///
    ///     geometry.cuttingEdgeProfile(.fillet(radius: 2), along: verticalEdges, in: selection.topology)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - edges: The edges to profile.
    ///   - topology: The mesh topology containing edge information.
    /// - Returns: A new geometry with the profile cut along the specified edges.
    ///
    func cuttingEdgeProfile(
        _ profile: EdgeProfile,
        along edges: [Edge],
        in topology: MeshTopology
    ) -> any Geometry3D {
        let profileGeometry = edges.mapUnion { edge in
            edge.profileGeometry(profile, in: topology, type: .subtraction)
        }
        return subtracting { profileGeometry }
    }

    /// Forms an edge profile along specific edges.
    ///
    /// Use this method when you need fine-grained control over which edges are profiled.
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - edges: The edges to profile.
    ///   - topology: The mesh topology containing edge information.
    /// - Returns: A new geometry with the profile formed along the specified edges.
    ///
    func formingEdgeProfile(
        _ profile: EdgeProfile,
        along edges: [Edge],
        in topology: MeshTopology
    ) -> any Geometry3D {
        let profileGeometry = edges.mapUnion { edge in
            edge.profileGeometry(profile, in: topology, type: .addition)
        }
        return adding { profileGeometry }
    }

    /// Cuts an edge profile along edges matching the specified criteria.
    ///
    /// This method provides a declarative way to select and profile edges without
    /// needing to use the `readingEdges` closure.
    ///
    /// ```swift
    /// // Chamfer only the vertical edges
    /// Box(10).cuttingEdgeProfile(.chamfer(depth: 1), along: .sharp().aligned(with: .z))
    ///
    /// // Fillet edges in the upper half
    /// Box(10).cuttingEdgeProfile(.fillet(radius: 2), along: .sharp().within(z: 0...))
    /// ```
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - criteria: The criteria for selecting edges to profile.
    ///   - continuityThreshold: The maximum angle between segments for them to form a single edge.
    ///     Default is 30°.
    /// - Returns: A new geometry with the profile cut along matching edges.
    ///
    func cuttingEdgeProfile(
        _ profile: EdgeProfile,
        along criteria: EdgeCriteria,
        continuityThreshold: Angle = 30°
    ) -> any Geometry3D {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let selection = criteria.apply(to: EdgeSelection(topology))
            let edges = selection.edges(continuityThreshold: continuityThreshold)

            let profileGeometry = edges.mapUnion { edge in
                edge.profileGeometry(profile, in: topology, type: .subtraction)
            }

            self.subtracting { profileGeometry }
        }
    }

    /// Forms an edge profile along edges matching the specified criteria.
    ///
    /// This method provides a declarative way to select and profile edges without
    /// needing to use the `readingEdges` closure.
    ///
    /// ```swift
    /// // Add material along vertical edges
    /// Box(10).formingEdgeProfile(.chamfer(depth: 1), along: .sharp().aligned(with: .z))
    /// ```
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - criteria: The criteria for selecting edges to profile.
    ///   - continuityThreshold: The maximum angle between segments for them to form a single edge.
    ///     Default is 30°.
    /// - Returns: A new geometry with the profile formed along matching edges.
    ///
    func formingEdgeProfile(
        _ profile: EdgeProfile,
        along criteria: EdgeCriteria,
        continuityThreshold: Angle = 30°
    ) -> any Geometry3D {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let selection = criteria.apply(to: EdgeSelection(topology))
            let edges = selection.edges(continuityThreshold: continuityThreshold)

            let profileGeometry = edges.mapUnion { edge in
                edge.profileGeometry(profile, in: topology, type: .addition)
            }

            self.adding { profileGeometry }
        }
    }
}
