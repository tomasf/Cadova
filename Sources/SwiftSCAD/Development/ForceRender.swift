import Foundation

struct ForceRender2D: WrappedGeometry2D {
    let body: any Geometry2D
    let convexity: Int
    
    var invocation: Invocation? {
        .init(name: "render", parameters: ["convexity": convexity])
    }
}

struct ForceRender3D: WrappedGeometry3D {
    let body: any Geometry3D
    let convexity: Int
    
    var invocation: Invocation? {
        .init(name: "render", parameters: ["convexity": convexity])
    }
}

public extension Geometry2D {
    func forceRendered(convexity: Int = 2) -> any Geometry2D {
        ForceRender2D(body: self, convexity: convexity)
    }
}

public extension Geometry3D {
    func forceRendered(convexity: Int = 2) -> any Geometry3D {
        ForceRender3D(body: self, convexity: convexity)
    }
}
