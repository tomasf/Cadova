import Foundation
import Manifold

internal protocol ExtrusionGeometry: Geometry3D {
    var body: any Geometry2D { get }
    func extrude(_ child: CrossSection) -> Mesh
}

extension ExtrusionGeometry {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(child: body, environment: environment, transformation: extrude(_:))
    }
}
