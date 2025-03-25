import Foundation
import Manifold3D

// Modify 2D output into either 2D or 3D output
internal struct ModifyOutput2D <DO: Dimensionality> {
    let body: Geometry2D
    let action: (Output2D, EnvironmentValues) -> Output<DO>
}

extension ModifyOutput2D: Geometry2D where DO == D2 {
    func evaluated(in environment: EnvironmentValues) -> Output<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

extension ModifyOutput2D: Geometry3D where DO == D3 {
    func evaluated(in environment: EnvironmentValues) -> Output<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

// Modify 3D output into either 2D or 3D output
internal struct ModifyOutput3D <DO: Dimensionality> {
    let body: Geometry3D
    let action: (Output3D, EnvironmentValues) -> Output<DO>
}

extension ModifyOutput3D: Geometry2D where DO == D2 {
    func evaluated(in environment: EnvironmentValues) -> Output<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

extension ModifyOutput3D: Geometry3D where DO == D3 {
    func evaluated(in environment: EnvironmentValues) -> Output<DO> {
        action(body.evaluated(in: environment), environment)
    }
}



internal extension Geometry2D {
    func modifyingOutput(_ action: @escaping (Output2D, EnvironmentValues) -> Output2D) -> any Geometry2D {
        ModifyOutput2D(body: self, action: action)
    }

    func modifyingOutput(_ action: @escaping (Output2D, EnvironmentValues) -> Output3D) -> any Geometry3D {
        ModifyOutput2D(body: self, action: action)
    }
}

internal extension Geometry3D {
    func modifyingOutput(_ action: @escaping (Output3D, EnvironmentValues) -> Output2D) -> any Geometry2D {
        ModifyOutput3D(body: self, action: action)
    }

    func modifyingOutput(_ action: @escaping (Output3D, EnvironmentValues) -> Output3D) -> any Geometry3D {
        ModifyOutput3D(body: self, action: action)
    }
}

internal extension Geometry2D {
    func modifyingPrimitive(_ action: @escaping (CrossSection, EnvironmentValues) -> CrossSection) -> Geometry2D {
        modifyingOutput { Output2D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (CrossSection) -> CrossSection) -> Geometry2D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPrimitive(_ action: @escaping (D2.Primitive, EnvironmentValues) -> D3.Primitive) -> Geometry3D {
        modifyingOutput { Output3D(primitive: action($0.primitive, $1), elements: $0.elements) }
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
    func modifyingPrimitive(_ action: @escaping (D3.Primitive, EnvironmentValues) -> D3.Primitive) -> Geometry3D {
        modifyingOutput { Output3D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive) -> D3.Primitive) -> Geometry3D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive, EnvironmentValues) -> D2.Primitive) -> Geometry2D {
        modifyingOutput { Output2D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }
}
