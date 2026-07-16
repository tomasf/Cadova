import Foundation

public extension Geometry3D {
    /// Adds debug geometry visualizing edges of this geometry matching a query.
    ///
    /// Each edge segment is shown as a cylinder and each joint between segments as a sphere.
    /// This is useful for verifying edge selection before applying profiles:
    ///
    /// ```swift
    /// Box(10).visualizingEdges(matching: .along(.z))
    /// ```
    ///
    /// The visualization's scale and color respond to the environment values
    /// (`withVisualizationScale(_:)` and `withVisualizationColor(_:)`).
    ///
    /// - Parameter query: The criteria used to select edges. Pass `.all` explicitly to visualize
    ///   every edge found under the default sharpness threshold.
    /// - Returns: This geometry with the matching edges visualized.
    ///
    func visualizingEdges(matching query: EdgeQuery) -> any Geometry3D {
        readingEdges(matching: query) { geometry, edges in
            geometry.adding { EdgeVisualization(edges: edges) }
        }
    }

    /// Adds debug geometry visualizing the given edges.
    ///
    /// Use this together with `readingEdges(matching:)` when you need programmatic control
    /// over edge selection:
    ///
    /// ```swift
    /// geometry.readingEdges(matching: .all) { geometry, edges in
    ///     geometry.visualizingEdges(edges.filter { $0.length > 5 })
    /// }
    /// ```
    ///
    /// The visualization's scale and color respond to the environment values
    /// (`withVisualizationScale(_:)` and `withVisualizationColor(_:)`).
    ///
    /// - Parameter edges: The edges to visualize, typically found by `readingEdges`.
    /// - Returns: This geometry with the given edges visualized.
    ///
    func visualizingEdges(_ edges: [FoundEdge]) -> any Geometry3D {
        adding { EdgeVisualization(edges: edges) }
    }
}

fileprivate struct EdgeVisualization: Shape3D {
    let edges: [FoundEdge]

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .edgeDefault

        edges.mapUnion { edge in
            edge.visualized(radius: 0.2 * scale)
        }
        .withSegmentation(count: 8)
        .colored(color)
        .inPart(.visualizedEdges)
    }
}

private extension FoundEdge {
    func visualized(radius: Double) -> any Geometry3D {
        segments.mapUnion { segment in
            segment.visualized(radius: radius)
        }
        .adding {
            if let last = segments.last {
                Sphere(radius: radius).translated(last.end)
            }
        }
    }
}

private extension EdgeSegment {
    func visualized(radius: Double) -> any Geometry3D {
        guard length > 1e-9 else { return Empty() }

        return Cylinder(radius: radius, height: length)
            .transformed(.rotation(from: .positiveZ, to: direction).translated(start))
            .adding {
                Sphere(radius: radius).translated(start)
            }
    }
}

fileprivate extension Color {
    static let edgeDefault: Self = .orange
}
