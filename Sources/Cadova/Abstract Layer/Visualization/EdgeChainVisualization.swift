import Foundation

public extension EdgeChain {
    /// Produces a 3D visualization of this edge chain for debugging and inspection.
    ///
    /// The visualization shows the edges as a series of connected cylinders.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the edges.
    ///
    /// - Parameter topology: The mesh topology containing the vertex positions.
    /// - Returns: A 3D geometry representing the edge chain.
    ///
    func visualized(in topology: MeshTopology) -> any Geometry3D {
        EdgeChainVisualization(chain: self, topology: topology)
    }
}

public extension Array where Element == EdgeChain {
    /// Produces a 3D visualization of multiple edge chains for debugging and inspection.
    ///
    /// Each chain is rendered as a series of connected cylinders.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the edges.
    ///
    /// - Parameter topology: The mesh topology containing the vertex positions.
    /// - Returns: A 3D geometry representing all edge chains.
    ///
    func visualized(in topology: MeshTopology) -> any Geometry3D {
        Union {
            for chain in self {
                chain.visualized(in: topology)
            }
        }
    }
}

public extension EdgeSelection {
    /// Produces a 3D visualization of the selected edges for debugging and inspection.
    ///
    /// The visualization shows each edge as a cylinder.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the edges.
    ///
    /// - Returns: A 3D geometry representing the selected edges.
    ///
    func visualized() -> any Geometry3D {
        EdgeSelectionVisualization(selection: self)
    }
}

fileprivate struct EdgeChainVisualization: Shape3D {
    let chain: EdgeChain
    let topology: MeshTopology

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .edgeDefault

        let vertices = chain.vertices(in: topology)

        Union {
            for (v1, v2) in vertices.paired() {
                VisualizedEdge(from: v1, to: v2, thickness: 0.15 * scale)
            }
        }
        .colored(color)
        .inPart(named: "Visualized Edge Chain", type: .visual)
    }
}

fileprivate struct EdgeSelectionVisualization: Shape3D {
    let selection: EdgeSelection

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .edgeDefault

        Union {
            for edge in selection.edges {
                let (v1, v2) = edge.vertices(in: selection.topology)
                VisualizedEdge(from: v1, to: v2, thickness: 0.15 * scale)
            }
        }
        .colored(color)
        .inPart(named: "Visualized Edges", type: .visual)
    }
}

fileprivate struct VisualizedEdge: Shape3D {
    let from: Vector3D
    let to: Vector3D
    let thickness: Double

    var body: any Geometry3D {
        Sphere(diameter: thickness)
            .translated(from)
            .adding {
                Sphere(diameter: thickness)
                    .translated(to)
            }
            .convexHull()
            .withSegmentation(count: 6)
    }
}

fileprivate extension Color {
    static let edgeDefault: Self = .orange
}
