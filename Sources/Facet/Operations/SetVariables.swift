import Foundation
import Manifold

internal struct SetVariables<Geometry> {
    let body: Geometry
    let variables: CodeFragment.Parameters
}

extension SetVariables<any Geometry2D>: Geometry2D, WrappedGeometry2D {
    func process(_ child: CrossSection) -> CrossSection { child }
}
extension SetVariables<any Geometry3D>: Geometry3D, WrappedGeometry3D {
    func process(_ child: Mesh) -> Mesh { child }
}
