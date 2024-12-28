import Foundation

public struct Empty<D: Dimensionality> {
    public func evaluated(in environment: EnvironmentValues) -> Output<D> { .empty }
}

extension Empty: Geometry3D where D == Dimensionality3 {
    public init() {}
}
extension Empty: Geometry2D where D == Dimensionality2 {
    public init() {}
}
