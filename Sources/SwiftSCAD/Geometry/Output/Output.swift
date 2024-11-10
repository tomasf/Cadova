import Foundation

public struct Output<V: Vector> {
    internal let codeFragment: CodeFragment
    internal let boundary: Boundary<V>
    internal let elements: ResultElementsByType

    init(codeFragment: CodeFragment, boundary: Boundary<V>, elements: ResultElementsByType) {
        self.codeFragment = codeFragment
        self.boundary = boundary
        self.elements = elements
    }

    // Combined geometry
    fileprivate init(
        childOutputs: [Output<V>],
        boundaryMergeStrategy: Boundary<V>.MergeStrategy,
        combination: GeometryCombination,
        moduleName: String,
        moduleParameters: CodeFragment.Parameters,
        supportsPreviewConvexity: Bool,
        environment: EnvironmentValues
    ) {
        var moduleParameters = moduleParameters
        if let convexity = environment.previewConvexity, supportsPreviewConvexity {
            moduleParameters["convexity"] = convexity
        }

        codeFragment = .init(
            module: moduleName,
            parameters: moduleParameters,
            body: childOutputs.map(\.codeFragment)
        )
        boundary = boundaryMergeStrategy.apply(childOutputs.map(\.boundary))
        elements = .init(combining: childOutputs.map(\.elements), operation: combination)
    }

    // Leaf
    init(
        moduleName: String,
        moduleParameters: CodeFragment.Parameters,
        boundary: Boundary<V>,
        supportsPreviewConvexity: Bool,
        environment: EnvironmentValues
    ) {
        var params = moduleParameters
        if let convexity = environment.previewConvexity, supportsPreviewConvexity {
            params["convexity"] = convexity
        }

        self.init(
            codeFragment: .init(module: moduleName, parameters: params, body: []),
            boundary: boundary,
            elements: [:]
        )
    }

    // Wrapped
    init(bodyOutput: Output<V>, moduleName: String, moduleParameters: CodeFragment.Parameters, boundary: (Boundary<V>) -> (Boundary<V>)) {
        self.init(
            codeFragment: .init(module: moduleName, parameters: moduleParameters, body: [bodyOutput.codeFragment]),
            boundary: boundary(bodyOutput.boundary),
            elements: bodyOutput.elements
        )
    }

    // Transformed
    fileprivate init(bodyOutput: Output<V>, moduleName: String, moduleParameters: CodeFragment.Parameters, transform: AffineTransform3D) {
        self.init(
            codeFragment: .init(module: moduleName, parameters: moduleParameters, body: [bodyOutput.codeFragment]),
            boundary: bodyOutput.boundary.transformed(.init(transform)),
            elements: bodyOutput.elements
        )
    }
}

internal extension Output where V == Vector2D {
    // Combined; union, difference, intersection, minkowski
    // Transparent for single children
    init(
        children: [Geometry2D],
        boundaryMergeStrategy: Boundary<V>.MergeStrategy,
        combination: GeometryCombination,
        moduleName: String,
        moduleParameters: CodeFragment.Parameters,
        environment: EnvironmentValues
    ) {
        if children.count == 1 {
            self = children[0].evaluated(in: environment)
        } else {
            self.init(
                childOutputs: children.map { $0.evaluated(in: environment) },
                boundaryMergeStrategy: boundaryMergeStrategy,
                combination: combination,
                moduleName: moduleName,
                moduleParameters: moduleParameters,
                supportsPreviewConvexity: false,
                environment: environment
            )
        }
    }

    // Transformed
    init(body: Geometry2D, moduleName: String, moduleParameters: CodeFragment.Parameters, transform: AffineTransform2D, environment: EnvironmentValues) {
        let environment = environment.applyingTransform(.init(transform))
        self.init(
            bodyOutput: body.evaluated(in: environment),
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            transform: transform.transform3D
        )
    }
}

internal extension Output where V == Vector3D {
    // Combined; union, difference, intersection, minkowski
    // Transparent for single children
    init(
        children: [Geometry3D],
        boundaryMergeStrategy: Boundary<V>.MergeStrategy,
        combination: GeometryCombination,
        moduleName: String,
        moduleParameters: CodeFragment.Parameters,
        supportsPreviewConvexity: Bool,
        environment: EnvironmentValues
    ) {
        if children.count == 1 {
            self = children[0].evaluated(in: environment)
        } else {
            let childEnvironment = supportsPreviewConvexity ? environment.withPreviewConvexity(nil) : environment
            self.init(
                childOutputs: children.map { $0.evaluated(in: childEnvironment) },
                boundaryMergeStrategy: boundaryMergeStrategy,
                combination: combination,
                moduleName: moduleName,
                moduleParameters: moduleParameters,
                supportsPreviewConvexity: supportsPreviewConvexity,
                environment: environment
            )
        }
    }

    // Extrusion
    init(
        child: Geometry2D,
        boundaryExtrusion: (Boundary2D, EnvironmentValues.Facets) -> Boundary3D,
        moduleName: String,
        moduleParameters: CodeFragment.Parameters,
        environment: EnvironmentValues
    ) {
        let childOutput = child.evaluated(in: environment.withPreviewConvexity(nil))

        var params = moduleParameters
        if let convexity = environment.previewConvexity {
            params["convexity"] = convexity
        }

        self.init(
            codeFragment: .init(module: moduleName, parameters: params, body: [childOutput.codeFragment]),
            boundary: boundaryExtrusion(childOutput.boundary, environment.facets),
            elements: childOutput.elements
        )
    }

    // Transformed
    init(body: Geometry3D, moduleName: String, moduleParameters: CodeFragment.Parameters, transform: AffineTransform3D, environment: EnvironmentValues) {
        let environment = environment.applyingTransform(.init(transform))
        self.init(
            bodyOutput: body.evaluated(in: environment),
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            transform: transform
        )
    }
}

public typealias Output2D = Output<Vector2D>
public typealias Output3D = Output<Vector3D>
