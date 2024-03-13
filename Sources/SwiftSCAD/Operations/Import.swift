import Foundation

public struct Import2D: LeafGeometry2D {
    let path: String
    let layer: String?
    let convexity: Int
    let center: Bool

    public init(path: String, dxfLayer: String? = nil, center: Bool = false, convexity: Int = 2) {
        self.path = path
        self.layer = dxfLayer
        self.convexity = convexity
        self.center = center
    }

    public var invocation: Invocation {
        .init(name: "import", parameters: [
            "file": path,
            "layer": layer,
            "convexity": convexity,
            "center": center
        ])
    }

    public var boundary: Bounds {
        // We don't know this; the import is done by OpenSCAD
        .empty
    }
}

public struct Import3D: LeafGeometry3D {
    let path: String
    let convexity: Int

    public init(path: String, convexity: Int = 2) {
        self.path = path
        self.convexity = convexity
    }

    public var invocation: Invocation {
        .init(name: "import", parameters: [
            "file": path,
            "convexity": convexity
        ])
    }

    public var boundary: Bounds {
        // We don't know this; the import is done by OpenSCAD
        .empty
    }
}
