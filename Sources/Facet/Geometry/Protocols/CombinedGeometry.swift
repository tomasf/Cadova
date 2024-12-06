import Foundation

internal protocol CombinedGeometry2D: Geometry2D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var children: [any Geometry2D] { get }
    var boundaryMergeStrategy: Boundary2D.MergeStrategy { get }
    var combination: GeometryCombination { get }
    var needsColorDeclaration: Bool { get }
}

extension CombinedGeometry2D {
    public func evaluated(in environment: EnvironmentValues) -> Output2D {
        .init(
            children: children,
            boundaryMergeStrategy: boundaryMergeStrategy,
            combination: combination,
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            declaresColor: needsColorDeclaration,
            environment: environment
        )
    }

    var moduleParameters: CodeFragment.Parameters { [:] }
    public var needsColorDeclaration: Bool { false }

}

internal protocol CombinedGeometry3D: Geometry3D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var supportsPreviewConvexity: Bool { get }
    var children: [any Geometry3D] { get }
    var boundaryMergeStrategy: Boundary3D.MergeStrategy { get }
    var combination: GeometryCombination { get }
    var needsColorDeclaration: Bool { get }
}

extension CombinedGeometry3D {
    public func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(
            children: children,
            boundaryMergeStrategy: boundaryMergeStrategy,
            combination: combination,
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            supportsPreviewConvexity: supportsPreviewConvexity,
            declaresColor: needsColorDeclaration,
            environment: environment
        )
    }

    var moduleParameters: CodeFragment.Parameters { [:] }
    var supportsPreviewConvexity: Bool { false }
    public var needsColorDeclaration: Bool { false }
}

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}
