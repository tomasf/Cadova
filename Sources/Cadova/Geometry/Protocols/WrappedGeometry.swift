import Foundation
import Manifold3D

internal protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    func process(_ output: Output2D, in environment: EnvironmentValues) -> Output2D
}

extension WrappedGeometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        process(body.evaluated(in: environment), in: environment)
    }
}

internal protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    func process(_ output: Output3D, in environment: EnvironmentValues) -> Output3D
}

extension WrappedGeometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        process(body.evaluated(in: environment), in: environment)
    }
}
