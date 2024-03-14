import Foundation

struct Fill2D: WrappedGeometry2D {
    let body: any Geometry2D

    var invocation: Invocation? {
        .init(name: "fill")
    }
}

public extension Geometry2D {
    func filled() -> any Geometry2D {
        Fill2D(body: self)
    }
}
