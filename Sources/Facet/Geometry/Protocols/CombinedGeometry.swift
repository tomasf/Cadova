import Foundation

internal protocol CombinedGeometry2D: Geometry2D {
    var children: [any Geometry2D] { get }
    var combination: GeometryCombination { get }
    func combine(_ children: [D2.Primitive], in environment: EnvironmentValues) -> D2.Primitive
}

extension CombinedGeometry2D {
    public func evaluated(in environment: EnvironmentValues) -> Output2D {
        .init(
            children: children,
            environment: environment,
            transformation: { combine($0, in: environment) },
            combination: combination)
    }
}

internal protocol CombinedGeometry3D: Geometry3D {
    var children: [any Geometry3D] { get }
    var combination: GeometryCombination { get }
    func combine(_ children: [D3.Primitive], in environment: EnvironmentValues) -> D3.Primitive
}

extension CombinedGeometry3D {
    public func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(
            children: children,
            environment: environment,
            transformation: { combine($0, in: environment) },
            combination: combination)
    }
}

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}
