import Foundation

internal protocol CombinedGeometry2D: Geometry2D {
    var invocationName: String { get }
    var children: [any Geometry2D] { get }
    var boundaryMergeStrategy: Boundary2D.MergeStrategy { get }
    var combination: GeometryCombination { get }
}

extension CombinedGeometry2D {
    func invocation(in environment: Environment) -> Invocation {
        .init(name: invocationName, body: children.map { $0.invocation(in: environment) })
    }

    func boundary(in environment: Environment) -> Boundary2D {
        let boundaries = children.map { $0.boundary(in: environment) }
        return boundaryMergeStrategy.apply(boundaries)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        let allAnchors = children.map { $0.anchors(in: environment) }
        return allAnchors.reduce(into: [:]) { $0.merge($1) { a, _ in a }}
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let allElements = children.map { $0.elements(in: environment) }
        return .init(combining: allElements, operation: combination)
    }
}

internal protocol CombinedGeometry3D: Geometry3D {
    var invocationName: String { get }
    var children: [any Geometry3D] { get }
    var boundaryMergeStrategy: Boundary3D.MergeStrategy { get }
    var combination: GeometryCombination { get }
}

extension CombinedGeometry3D {
    func invocation(in environment: Environment) -> Invocation {
        .init(name: invocationName, body: children.map { $0.invocation(in: environment) })
    }

    func boundary(in environment: Environment) -> Boundary3D {
        let boundaries = children.map { $0.boundary(in: environment) }
        return boundaryMergeStrategy.apply(boundaries)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        let allAnchors = children.map { $0.anchors(in: environment) }
        return allAnchors.reduce(into: [:]) { $0.merge($1) { a, _ in a }}
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        let allElements = children.map { $0.elements(in: environment) }
        return .init(combining: allElements, operation: combination)
    }
}

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}
