import Foundation
import Manifold3D

public extension Geometry3D {
    /// Reads the mesh topology of this geometry and allows edge-based queries.
    ///
    /// This method evaluates the geometry to a concrete mesh and provides access
    /// to its edge topology for selection and filtering operations.
    ///
    /// ```swift
    /// myGeometry.readingEdges { edges in
    ///     let sharpEdges = edges
    ///         .sharp(threshold: 160°)
    ///         .within(boundingBox)
    ///     // Use sharpEdges.edges or sharpEdges.chained()
    ///     ...
    /// }
    /// ```
    ///
    /// - Parameter reader: A closure that receives an `EdgeSelection` containing all edges
    ///   in the mesh. Apply filters to narrow down the selection.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingEdges<Output: Dimensionality>(
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (EdgeSelection) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let selection = EdgeSelection(topology)
            return reader(selection)
        }
    }

    /// Reads the mesh topology of this geometry and returns edge chains.
    ///
    /// This is a convenience method that evaluates the geometry, finds sharp edges,
    /// and chains them into connected sequences.
    ///
    /// ```swift
    /// myGeometry.readingEdgeChains(sharpnessThreshold: 160°) { chains in
    ///     for chain in chains {
    ///         // Process each chain
    ///     }
    ///     ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 170°.
    ///   - continuityThreshold: The maximum angle between edges for them to be chained together.
    ///     Default is 30°.
    ///   - reader: A closure that receives the edge chains and mesh topology.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingEdgeChains<Output: Dimensionality>(
        sharpnessThreshold: Angle = 170°,
        continuityThreshold: Angle = 30°,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping ([EdgeChain], MeshTopology) -> Output.Geometry
    ) -> Output.Geometry {
        readingEdges { selection in
            let chains = selection
                .sharp(threshold: sharpnessThreshold)
                .chained(continuityThreshold: continuityThreshold)
            return reader(chains, selection.topology)
        }
    }
}
