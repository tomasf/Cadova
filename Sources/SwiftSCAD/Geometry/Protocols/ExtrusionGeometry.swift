import Foundation

internal protocol ExtrusionGeometry: Geometry3D {
    var body: any Geometry2D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    func boundary(for boundary2D: Boundary2D, facets: Environment.Facets) -> Boundary3D
}

extension ExtrusionGeometry {
    func bodyEnvironment(for environment: Environment) -> Environment {
        environment.withPreviewConvexity(nil)
    }

    func codeFragment(in environment: Environment) -> CodeFragment {

        var parameters = moduleParameters
        if let previewConvexity = environment.previewConvexity {
            parameters["convexity"] = previewConvexity
        }

        return CodeFragment(
            module: moduleName,
            parameters: parameters,
            body: [body.codeFragment(in: bodyEnvironment(for: environment))]
        )
    }

    func boundary(in environment: Environment) -> Bounds {
        boundary(
            for: body.boundary(in: bodyEnvironment(for: environment)),
            facets: environment.facets
        )
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(for: environment))
    }
}
