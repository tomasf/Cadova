import Foundation
import Manifold3D

internal protocol ExtrusionGeometry: Geometry3D {
    var body: any Geometry2D { get }
    func extrude(_ child: CrossSection, in environment: EnvironmentValues) -> D3.Primitive
}

extension ExtrusionGeometry {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(child: body, environment: environment, transformation: { extrude($0, in: environment) })
    }
}
