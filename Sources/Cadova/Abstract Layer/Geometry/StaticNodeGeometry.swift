import Foundation

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
