import Foundation

internal protocol LeafGeometry2D: Geometry2D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    func boundary(in environment: Environment) -> Bounds
}

extension LeafGeometry2D {
    public func evaluated(in environment: Environment) -> Output {
        .init(
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            boundary: boundary(in: environment),
            supportsPreviewConvexity: false,
            environment: environment
        )
    }
}

internal protocol LeafGeometry3D: Geometry3D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    func boundary(in environment: Environment) -> Bounds
    var supportsPreviewConvexity: Bool { get }
}

extension LeafGeometry3D {
    public func evaluated(in environment: Environment) -> Output {
        .init(
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            boundary: boundary(in: environment),
            supportsPreviewConvexity: supportsPreviewConvexity,
            environment: environment
        )
    }

    var supportsPreviewConvexity: Bool { false }
}
