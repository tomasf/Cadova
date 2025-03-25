import Foundation
import Manifold3D

internal struct ReadPrimitive <D: Dimensionality> {
    let body: D.Geometry
    let action: (D.Primitive, EnvironmentValues, ResultElementsByType) -> D.Geometry
}

extension ReadPrimitive: Geometry2D where D == D2 {
    func evaluated(in environment: EnvironmentValues) -> Output<D> {
        let bodyOutput = body.evaluated(in: environment)
        return action(bodyOutput.primitive, environment, bodyOutput.elements).evaluated(in: environment)
    }
}

extension ReadPrimitive: Geometry3D where D == D3 {
    func evaluated(in environment: EnvironmentValues) -> Output<D> {
        let bodyOutput = body.evaluated(in: environment)
        return action(bodyOutput.primitive, environment, bodyOutput.elements).evaluated(in: environment)
    }
}

internal extension Geometry2D {
    func readingPrimitive(_ action: @escaping (D.Primitive, EnvironmentValues, ResultElementsByType) -> D.Geometry) -> D.Geometry {
        ReadPrimitive(body: self, action: action)
    }
}

internal extension Geometry3D {
    func readingPrimitive(_ action: @escaping (D.Primitive, EnvironmentValues, ResultElementsByType) -> D.Geometry) -> D.Geometry {
        ReadPrimitive(body: self, action: action)
    }
}
