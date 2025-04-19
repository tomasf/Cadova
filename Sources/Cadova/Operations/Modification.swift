import Foundation
import Manifold3D

/*

// Modify 2D output into either 2D or 3D output
internal struct ModifyGeometryResult2D <DO: Dimensionality> {
    let body: Geometry2D
    let action: (GeometryResult2D, EnvironmentValues) -> GeometryResult<DO>
}

extension ModifyGeometryResult2D: Geometry2D where DO == D2 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

extension ModifyGeometryResult2D: Geometry3D where DO == D3 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

// Modify 3D output into either 2D or 3D output
internal struct ModifyGeometryResult3D <DO: Dimensionality> {
    let body: Geometry3D
    let action: (GeometryResult3D, EnvironmentValues) -> GeometryResult<DO>
}

extension ModifyGeometryResult3D: Geometry2D where DO == D2 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult<DO> {
        action(body.evaluated(in: environment), environment)
    }
}

extension ModifyGeometryResult3D: Geometry3D where DO == D3 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult<DO> {
        action(body.evaluated(in: environment), environment)
    }
}



internal extension Geometry2D {
    func modifyingOutput(_ action: @escaping (GeometryResult2D, EnvironmentValues) -> GeometryResult2D) -> any Geometry2D {
        ModifyGeometryResult2D(body: self, action: action)
    }

    func modifyingOutput(_ action: @escaping (GeometryResult2D, EnvironmentValues) -> GeometryResult3D) -> any Geometry3D {
        ModifyGeometryResult2D(body: self, action: action)
    }
}

internal extension Geometry3D {
    func modifyingOutput(_ action: @escaping (GeometryResult3D, EnvironmentValues) -> GeometryResult2D) -> any Geometry2D {
        ModifyGeometryResult3D(body: self, action: action)
    }

    func modifyingOutput(_ action: @escaping (GeometryResult3D, EnvironmentValues) -> GeometryResult3D) -> any Geometry3D {
        ModifyGeometryResult3D(body: self, action: action)
    }
}

internal extension Geometry2D {
    func modifyingPrimitive(_ action: @escaping (CrossSection, EnvironmentValues) -> CrossSection) -> Geometry2D {
        modifyingOutput { GeometryResult2D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (CrossSection) -> CrossSection) -> Geometry2D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPrimitive(_ action: @escaping (D2.Primitive, EnvironmentValues) -> D3.Primitive) -> Geometry3D {
        modifyingOutput { GeometryResult3D(primitive: action($0.primitive, $1), elements: $0.elements) }
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
        modifyingOutput { GeometryResult3D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive) -> D3.Primitive) -> Geometry3D {
        modifyingPrimitive { p, e in action(p) }
    }

    func modifyingPrimitive(_ action: @escaping (D3.Primitive, EnvironmentValues) -> D2.Primitive) -> Geometry2D {
        modifyingOutput { GeometryResult2D(primitive: action($0.primitive, $1), elements: $0.elements) }
    }
}

*/
