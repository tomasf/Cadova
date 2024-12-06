import Foundation

internal protocol ExtrusionGeometry: Geometry3D {
    var body: any Geometry2D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    func boundary(for boundary2D: Boundary2D, facets: EnvironmentValues.Facets) -> Boundary3D
}

extension ExtrusionGeometry {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        return .init(child: body, boundaryExtrusion: {
            boundary(for: $0, facets: $1)
        }, moduleName: moduleName, moduleParameters: moduleParameters, environment: environment)
    }
}
