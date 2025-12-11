import Foundation
import Manifold3D

public extension Geometry3D {
    /// Cuts an edge profile along the sharp edges of this geometry.
    ///
    /// This method identifies sharp edges in the mesh, chains them together, and applies
    /// the specified edge profile along each chain.
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
    ///   - continuityThreshold: The maximum angle between edges for them to be chained together.
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
            let selection = EdgeSelection(topology)
            let chains = selection
                .sharp(threshold: sharpnessThreshold)
                .chained(continuityThreshold: continuityThreshold)

            let profileGeometry = chains.mapUnion { chain in
                chain.profileGeometry(profile, in: topology, type: .subtraction)
            }

            self.subtracting { profileGeometry }
        }
    }

    /// Forms an edge profile along the sharp edges of this geometry.
    ///
    /// This method identifies sharp edges in the mesh, chains them together, and adds
    /// the specified edge profile along each chain.
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply (e.g., chamfer or fillet).
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 100° (edges with angles less than this are profiled).
    ///   - continuityThreshold: The maximum angle between edges for them to be chained together.
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
            let selection = EdgeSelection(topology)
            let chains = selection
                .sharp(threshold: sharpnessThreshold)
                .chained(continuityThreshold: continuityThreshold)

            let profileGeometry = chains.mapUnion { chain in
                chain.profileGeometry(profile, in: topology, type: .addition)
            }

            self.adding { profileGeometry }
        }
    }

    /// Cuts an edge profile along specific edge chains.
    ///
    /// Use this method when you need fine-grained control over which edges are profiled.
    /// First use `readingEdges` to select and filter edges, then apply the profile.
    ///
    /// ```swift
    /// myGeometry.readingEdges { geometry, edges in
    ///     let verticalChains = edges
    ///         .sharp(threshold: 100°)
    ///         .aligned(with: .z)
    ///         .chained()
    ///
    ///     geometry.cuttingEdgeProfile(.fillet(radius: 2), along: verticalChains, in: edges.topology)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - chains: The edge chains to profile.
    ///   - topology: The mesh topology containing edge information.
    /// - Returns: A new geometry with the profile cut along the specified chains.
    ///
    func cuttingEdgeProfile(
        _ profile: EdgeProfile,
        along chains: [EdgeChain],
        in topology: MeshTopology
    ) -> any Geometry3D {
        let profileGeometry = chains.mapUnion { chain in
            chain.profileGeometry(profile, in: topology, type: .subtraction)
        }
        return subtracting { profileGeometry }
    }

    /// Forms an edge profile along specific edge chains.
    ///
    /// Use this method when you need fine-grained control over which edges are profiled.
    ///
    /// - Parameters:
    ///   - profile: The edge profile to apply.
    ///   - chains: The edge chains to profile.
    ///   - topology: The mesh topology containing edge information.
    /// - Returns: A new geometry with the profile formed along the specified chains.
    ///
    func formingEdgeProfile(
        _ profile: EdgeProfile,
        along chains: [EdgeChain],
        in topology: MeshTopology
    ) -> any Geometry3D {
        let profileGeometry = chains.mapUnion { chain in
            chain.profileGeometry(profile, in: topology, type: .addition)
        }
        return adding { profileGeometry }
    }
}
