import Foundation

internal protocol CombinedGeometry2D: Geometry2D {
    var children: [any Geometry2D] { get }
    var combination: GeometryCombination { get }
    func combine(_ children: [Dimensionality2.Primitive]) -> Dimensionality2.Primitive
}

extension CombinedGeometry2D {
    public func evaluated(in environment: EnvironmentValues) -> Output2D {
        .init(
            children: children,
            environment: environment,
            transformation: combine(_:),
            combination: combination)
    }
}

internal protocol CombinedGeometry3D: Geometry3D {
    var children: [any Geometry3D] { get }
    var combination: GeometryCombination { get }
    func combine(_ children: [Dimensionality3.Primitive]) -> Dimensionality3.Primitive
}

extension CombinedGeometry3D {
    public func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(
            children: children,
            environment: environment,
            transformation: combine(_:),
            combination: combination)
    }
}

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}
