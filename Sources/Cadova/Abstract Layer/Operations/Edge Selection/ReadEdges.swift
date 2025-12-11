import Foundation
import Manifold3D

public extension Geometry3D {
    /// Reads the mesh topology of this geometry and allows edge-based queries.
    ///
    /// This method evaluates the geometry to a concrete mesh and provides access
    /// to its edge topology for selection and filtering operations.
    ///
    /// ```swift
    /// myGeometry.readingEdges { geometry, edges in
    ///     let sharpEdges = edges
    ///         .sharp(threshold: 160°)
    ///         .within(boundingBox)
    ///     geometry.cuttingEdgeProfile(.chamfer(depth: 2), along: sharpEdges.chained(), in: edges.topology)
    /// }
    /// ```
    ///
    /// - Parameter reader: A closure that receives the geometry and an `EdgeSelection` containing
    ///   all edges in the mesh. Apply filters to narrow down the selection.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingEdges<Output: Dimensionality>(
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ edges: EdgeSelection) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let selection = EdgeSelection(topology)
            return reader(self, selection)
        }
    }

    /// Reads the mesh topology of this geometry and returns edge chains.
    ///
    /// This is a convenience method that evaluates the geometry, finds sharp edges,
    /// and chains them into connected sequences.
    ///
    /// ```swift
    /// myGeometry.readingEdgeChains(sharpnessThreshold: 160°) { geometry, chains, topology in
    ///     geometry.cuttingEdgeProfile(.fillet(radius: 2), along: chains, in: topology)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 170°.
    ///   - continuityThreshold: The maximum angle between edges for them to be chained together.
    ///     Default is 30°.
    ///   - reader: A closure that receives the geometry, edge chains, and mesh topology.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingEdgeChains<Output: Dimensionality>(
        sharpnessThreshold: Angle = 170°,
        continuityThreshold: Angle = 30°,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ chains: [EdgeChain], _ topology: MeshTopology) -> Output.Geometry
    ) -> Output.Geometry {
        readingEdges { geometry, selection in
            let chains = selection
                .sharp(threshold: sharpnessThreshold)
                .chained(continuityThreshold: continuityThreshold)
            return reader(geometry, chains, selection.topology)
        }
    }
}
