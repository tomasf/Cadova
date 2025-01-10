import Foundation

public struct Empty<D: Dimensionality>: LeafGeometry {
    typealias D = D
    var body: D.Primitive { .empty }
}

extension Empty: Geometry3D where D == D3 {
    public init() {}
}

extension Empty: Geometry2D where D == D2 {
    public init() {}
}
