import Foundation
import Manifold3D

internal struct ModifyPrimitive <D: Dimensionality> {
    let body: D.Geometry
    let action: (D.Primitive, EnvironmentValues) -> D.Primitive

    func process(_ child: D.Primitive, in environment: EnvironmentValues) -> D.Primitive {
        action(child, environment)
    }
}

extension ModifyPrimitive: WrappedGeometry2D, Geometry2D where D == D2 {}
extension ModifyPrimitive: WrappedGeometry3D, Geometry3D where D == D3 {}

internal extension Geometry2D {
    func modifyingPrimitive(_ action: @escaping (CrossSection, EnvironmentValues) -> CrossSection) -> Geometry2D {
        ModifyPrimitive(body: self, action: action)
    }

    func modifyingPrimitive(_ action: @escaping (CrossSection) -> CrossSection) -> Geometry2D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPolygons(_ action: @escaping ([[Vector2D]], EnvironmentValues) -> [[Vector2D]]) -> Geometry2D {
        modifyingPrimitive { crossSection, environment in
            let newPolygons = action(crossSection.polygons().map { $0.vertices.map(\.vector2D) }, environment)
            return .init(polygons: newPolygons.map { Manifold3D.Polygon(vertices: $0) }, fillRule: .evenOdd)
        }
    }
}

internal extension Geometry3D {
    func modifyingPrimitive(_ action: @escaping (D3.Primitive, EnvironmentValues) -> D3.Primitive) -> Geometry3D {
        ModifyPrimitive(body: self, action: action)
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive) -> D3.Primitive) -> Geometry3D {
        modifyingPrimitive { p, e in action(p) }
    }
}
