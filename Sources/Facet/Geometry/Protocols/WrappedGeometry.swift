import Foundation
import Manifold3D

internal protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    func process(_ child: CrossSection, in environment: EnvironmentValues) -> CrossSection
}

extension WrappedGeometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(wrapping: body, environment: environment, transformation: { process($0, in: environment) })
    }
}

internal protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    func process(_ child: D3.Primitive, in environment: EnvironmentValues) -> D3.Primitive
}

extension WrappedGeometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(wrapping: body, environment: environment, transformation: { process($0, in: environment) })
    }
}
