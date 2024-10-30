import Foundation

internal protocol CombinedGeometry2D: Geometry2D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var children: [any Geometry2D] { get }
    var boundaryMergeStrategy: Boundary2D.MergeStrategy { get }
    var combination: GeometryCombination { get }
}

extension CombinedGeometry2D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(module: moduleName, parameters: moduleParameters, body: children.map { $0.codeFragment(in: environment) })
    }

    func boundary(in environment: Environment) -> Boundary2D {
        let boundaries = children.map { $0.boundary(in: environment) }
        return boundaryMergeStrategy.apply(boundaries)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let allElements = children.map { $0.elements(in: environment) }
        return .init(combining: allElements, operation: combination)
    }

    var moduleParameters: CodeFragment.Parameters { [:] }
}

internal protocol CombinedGeometry3D: Geometry3D {
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var children: [any Geometry3D] { get }
    var boundaryMergeStrategy: Boundary3D.MergeStrategy { get }
    var combination: GeometryCombination { get }
}

extension CombinedGeometry3D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(module: moduleName, parameters: moduleParameters, body: children.map { $0.codeFragment(in: environment) })
    }

    func boundary(in environment: Environment) -> Boundary3D {
        let boundaries = children.map { $0.boundary(in: environment) }
        return boundaryMergeStrategy.apply(boundaries)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let allElements = children.map { $0.elements(in: environment) }
        return .init(combining: allElements, operation: combination)
    }

    var moduleParameters: CodeFragment.Parameters { [:] }
}

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}
