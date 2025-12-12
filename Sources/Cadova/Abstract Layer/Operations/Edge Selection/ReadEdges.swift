import Foundation
import Manifold3D

public extension Geometry3D {
    /// Reads the mesh topology of this geometry and allows edge-based queries.
    ///
    /// This method evaluates the geometry to a concrete mesh and provides access
    /// to its edge topology for selection and filtering operations.
    ///
    /// ```swift
    /// myGeometry.readingEdges { geometry, selection in
    ///     let sharpEdges = selection
    ///         .sharp(threshold: 160°)
    ///         .within(boundingBox)
    ///         .edges
    ///     geometry.cuttingEdgeProfile(.chamfer(depth: 2), along: sharpEdges, in: selection.topology)
    /// }
    /// ```
    ///
    /// - Parameter reader: A closure that receives the geometry and an `EdgeSelection` containing
    ///   all edges in the mesh. Apply filters to narrow down the selection.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingEdges<Output: Dimensionality>(
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ selection: EdgeSelection) -> Output.Geometry
    ) -> Output.Geometry {
        readingConcrete { (manifold: Manifold) in
            let topology = MeshTopology(manifold: manifold)
            let selection = EdgeSelection(topology)
            return reader(self, selection)
        }
    }

    /// Reads the mesh topology of this geometry and returns sharp edges.
    ///
    /// This is a convenience method that evaluates the geometry and finds sharp edges.
    ///
    /// ```swift
    /// myGeometry.readingSharpEdges(sharpnessThreshold: 160°) { geometry, edges, topology in
    ///     geometry.cuttingEdgeProfile(.fillet(radius: 2), along: edges, in: topology)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sharpnessThreshold: The maximum dihedral angle for edges to be considered sharp.
    ///     Default is 170°.
    ///   - continuityThreshold: The maximum angle between segments for them to form a single edge.
    ///     Default is 30°.
    ///   - reader: A closure that receives the geometry, sharp edges, and mesh topology.
    /// - Returns: The geometry returned by the reader closure.
    ///
    func readingSharpEdges<Output: Dimensionality>(
        sharpnessThreshold: Angle = 170°,
        continuityThreshold: Angle = 30°,
        @GeometryBuilder<Output> _ reader: @Sendable @escaping (_ geometry: any Geometry3D, _ edges: [Edge], _ topology: MeshTopology) -> Output.Geometry
    ) -> Output.Geometry {
        readingEdges { geometry, selection in
            let edges = selection
                .sharp(threshold: sharpnessThreshold)
                .edges(continuityThreshold: continuityThreshold)
            return reader(geometry, edges, selection.topology)
        }
    }
}
