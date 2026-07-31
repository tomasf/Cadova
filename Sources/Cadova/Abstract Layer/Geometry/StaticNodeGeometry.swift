import Foundation

/// Wraps an already-resolved `GeometryNode` as a `Geometry` value, with no further building
/// required. Used by leaf shapes (e.g. `Box`, `Circle`) as the concrete `body` they return.
struct StaticNodeGeometry<D: Dimensionality>: Geometry {
    let node: D.Node

    init(_ node: D.Node) {
        self.node = node
    }

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        .init(node)
    }
}

extension StaticNodeGeometry<D2> {
    init(_ shape: GeometryNode<D2>.PrimitiveShape2D) {
        self.init(.shape(shape))
    }
}

extension StaticNodeGeometry<D3> {
    init(_ shape: GeometryNode<D3>.PrimitiveShape3D) {
        self.init(.shape(shape))
    }
}
