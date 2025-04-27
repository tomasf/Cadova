import Foundation
import Manifold3D

internal func LazyUnion<D: Dimensionality>(lazy: Bool, children: [D.Geometry]) -> D.Geometry {
    if lazy, let children = children as? [any Geometry3D] {
        GeometryExpressionTransformer<D3, D3>(bodies: children) { .lazyUnion($0) } as! D.Geometry
    } else {
        Union(children)
    }
}

internal func LazyUnion<D: Dimensionality>(lazy: Bool, @ArrayBuilder<D.Geometry> _ body: () -> [D.Geometry]) -> D.Geometry {
    LazyUnion(lazy: lazy, children: body())
}

internal func LazyUnion<D: Dimensionality>(lazy: Bool, @ArrayBuilder<D.Geometry> _ body: () async -> [D.Geometry]) async -> D.Geometry {
    await LazyUnion(lazy: lazy, children: body())
}
