import Foundation

public extension Edge {
    /// Produces a 3D visualization of this edge for debugging and inspection.
    ///
    /// The visualization shows the edge as a series of connected cylinders.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the edge.
    ///
    /// - Parameter topology: The mesh topology containing the vertex positions.
    /// - Returns: A 3D geometry representing the edge.
    ///
    func visualized(in topology: MeshTopology) -> any Geometry3D {
        EdgeVisualization(edge: self, topology: topology)
    }
}

public extension Array where Element == Edge {
    /// Produces a 3D visualization of multiple edges for debugging and inspection.
    ///
    /// Each edge is rendered as a series of connected cylinders.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the edges.
    ///
    /// - Parameter topology: The mesh topology containing the vertex positions.
    /// - Returns: A 3D geometry representing all edges.
    ///
    func visualized(in topology: MeshTopology) -> any Geometry3D {
        Union {
            for edge in self {
                edge.visualized(in: topology)
            }
        }
    }
}

public extension EdgeSelection {
    /// Produces a 3D visualization of the selected edge segments for debugging and inspection.
    ///
    /// The visualization shows each segment as a cylinder.
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts overall thickness of the cylinders.
    /// - `withVisualizationColor(_:)` sets the color of the segments.
    ///
    /// - Returns: A 3D geometry representing the selected segments.
    ///
    func visualized() -> any Geometry3D {
        EdgeSelectionVisualization(selection: self)
    }
}

fileprivate struct EdgeVisualization: Shape3D {
    let edge: Edge
    let topology: MeshTopology

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .edgeDefault

        let vertices = edge.vertices(in: topology)

        Union {
            for (v1, v2) in vertices.paired() {
                VisualizedSegment(from: v1, to: v2, thickness: 0.15 * scale)
            }
        }
        .colored(color)
        .inPart(named: "Visualized Edge", type: .visual)
    }
}

fileprivate struct EdgeSelectionVisualization: Shape3D {
    let selection: EdgeSelection

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .edgeDefault

        Union {
            for segment in selection.segments {
                let (v1, v2) = segment.vertices(in: selection.topology)
                VisualizedSegment(from: v1, to: v2, thickness: 0.15 * scale)
            }
        }
        .colored(color)
        .inPart(named: "Visualized Segments", type: .visual)
    }
}

fileprivate struct VisualizedSegment: Shape3D {
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
