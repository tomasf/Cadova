import Foundation

public struct Import3D: CoreGeometry3D {
    let path: String
    let convexity: Int

    public init(path: String, convexity: Int = 2) {
        self.path = path
        self.convexity = convexity
    }

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "import",
            params: [
                "file": path,
                "convexity": convexity
            ]
        )
    }
}

public struct Import2D: CoreGeometry2D {
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

    func call(in environment: Environment) -> SCADCall {
        let params: [String: (any SCADValue)?] = [
            "file": path,
            "layer": layer,
            "convexity": convexity,
            "center": center
        ]
        return SCADCall(
            name: "import",
            params: params.compactMapValues { $0 }
        )
    }
}
