import Foundation
import Manifold

internal protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    func process(_ child: CrossSection) -> CrossSection
}

extension WrappedGeometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(wrapping: body, environment: environment, transformation: process(_:))
    }
}

internal protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    func process(_ child: Mesh) -> Mesh
}

extension WrappedGeometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(wrapping: body, environment: environment, transformation: process(_:))
    }
}
