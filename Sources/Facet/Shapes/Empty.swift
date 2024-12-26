import Foundation

internal struct Empty<D: Dimensionality> {
    func evaluated(in environment: EnvironmentValues) -> Output<D> { .empty }
}

extension Empty: Geometry3D where D == Dimensionality3 {}
extension Empty: Geometry2D where D == Dimensionality2 {}

public extension Geometry2D {
    static var empty: any Geometry2D { Empty() }
}

public extension Geometry3D {
    static var empty: any Geometry3D { Empty() }
}
