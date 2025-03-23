import Foundation
import Manifold3D

internal struct ModifyOutput <D: Dimensionality> {
    let body: D.Geometry
    let action: (Output<D>, EnvironmentValues) -> Output<D>

    func process(_ output: Output<D>, in environment: EnvironmentValues) -> Output<D> {
        action(output, environment)
    }
}

extension ModifyOutput: WrappedGeometry2D, Geometry2D where D == D2 {}
extension ModifyOutput: WrappedGeometry3D, Geometry3D where D == D3 {}

internal extension Geometry2D {
    func modifyingOutput(_ action: @escaping (Output2D, EnvironmentValues) -> Output2D) -> any Geometry2D {
        ModifyOutput(body: self, action: action)
    }
}

internal extension Geometry2D {
    func modifyingPrimitive(_ action: @escaping (CrossSection, EnvironmentValues) -> CrossSection) -> Geometry2D {
        modifyingOutput { Output2D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (CrossSection) -> CrossSection) -> Geometry2D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPolygons(_ action: @escaping ([[Vector2D]], EnvironmentValues) -> [[Vector2D]]) -> Geometry2D {
        modifyingPrimitive { crossSection, environment in
            let inputPoints: [[Vector2D]] = crossSection.polygons().map { $0.vertices.map(\.vector2D) }
            let newPoints: [[Vector2D]] = action(inputPoints, environment)
            let newPolygons = newPoints.map { Manifold3D.Polygon(vertices: $0) }
            return CrossSection(polygons: newPolygons, fillRule: .evenOdd)
        }
    }
}


internal extension Geometry3D {
    func modifyingOutput(_ action: @escaping (Output3D, EnvironmentValues) -> Output3D) -> any Geometry3D {
        ModifyOutput(body: self, action: action)
    }
}

internal extension Geometry3D {
    func modifyingPrimitive(_ action: @escaping (D3.Primitive, EnvironmentValues) -> D3.Primitive) -> Geometry3D {
        modifyingOutput { Output3D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive) -> D3.Primitive) -> Geometry3D {
        modifyingPrimitive { p, e in action(p) }
    }
}
