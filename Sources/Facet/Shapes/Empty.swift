import Foundation

internal struct Empty<D: Dimensionality> {
    func evaluated(in environment: EnvironmentValues) -> Output<D> { .empty }
}

extension Empty: Geometry3D where D == Dimensionality3 {}
extension Empty: Geometry2D where D == Dimensionality2 {}
