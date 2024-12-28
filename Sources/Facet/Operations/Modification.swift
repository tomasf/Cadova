import Foundation
import Manifold

internal struct ModifyPrimitive <D: Dimensionality> {
    let body: D.Geometry
    let action: (D.Primitive, EnvironmentValues) -> D.Primitive

    func process(_ child: D.Primitive, in environment: EnvironmentValues) -> D.Primitive {
        action(child, environment)
    }
}

extension ModifyPrimitive: WrappedGeometry2D, Geometry2D where D == Dimensionality2 {}
extension ModifyPrimitive: WrappedGeometry3D, Geometry3D where D == Dimensionality3 {}

internal extension Geometry2D {
    func modifyingPrimitive(_ action: @escaping (CrossSection, EnvironmentValues) -> CrossSection) -> Geometry2D {
        ModifyPrimitive(body: self, action: action)
    }
}

internal extension Geometry3D {
    func modifyingPrimitive(_ action: @escaping (Mesh, EnvironmentValues) -> Mesh) -> Geometry3D {
        ModifyPrimitive(body: self, action: action)
    }
}
