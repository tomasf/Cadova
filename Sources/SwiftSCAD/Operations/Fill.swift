import Foundation

struct Fill2D: CoreGeometry2D {
    let body: Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "fill", body: body)
    }
}

public extension Geometry2D {
    func filled() -> Geometry2D {
        Fill2D(body: self)
    }
}
