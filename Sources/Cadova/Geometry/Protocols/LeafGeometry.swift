import Foundation
import Manifold3D

internal protocol LeafGeometry<D> {
    associatedtype D: Dimensionality
    var body: D.Primitive { get }
}

extension LeafGeometry {
    public func evaluated(in environment: EnvironmentValues) -> GeometryResult<D> {
        environment.whileCurrent {
            GeometryResult(primitive: body)
        }
    }
}
