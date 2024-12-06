import Foundation

/// Import 2D content from external files
public struct Import2D: LeafGeometry2D {
    let path: String
    let layer: String?
    let center: Bool

    /// Initializes a new `Import2D` instance for importing 2D geometries.
    ///
    /// Supported formats are DXF and SVG. Because importing is done by OpenSCAD at rendertime, Facet has no knowledge of the resulting geometry and it will have no bounding box. If you need to use it with operations that require a bounding box, you can declare it manually using `settingBounds(_:)`.
    ///
    /// - Parameters:
    ///   - path: The file path to the 2D geometry to be imported. Paths are resolved relative to the .scad file if not absolute.
    ///   - dxfLayer: Optionally specifies a layer to import from a DXF file. This parameter has no effect for SVG files.
    ///   - center: Determines if the imported geometry should be centered around the origin. Defaults to `false`.
    public init(path: String, dxfLayer: String? = nil, center: Bool = false) {
        self.path = (path as NSString).expandingTildeInPath
        self.layer = dxfLayer
        self.center = center
    }

    func boundary(in environment: EnvironmentValues) -> Bounds {
        .empty // We don't know this; the import is done by OpenSCAD
    }

    let moduleName = "import"
    var moduleParameters: CodeFragment.Parameters {
        [
            "file": path,
            "layer": layer,
            "center": center
        ]
    }
}

/// Import 3D content from external files
public struct Import3D: LeafGeometry3D {
    let path: String

    /// Initializes a new `Import3D` instance for importing 3D models.
    ///
    /// Supported formats are STL, OFF, AMF and 3MF. Because importing is done by OpenSCAD at rendertime, Facet has no knowledge of the resulting geometry and it will have no bounding box. If you need to use it with operations that require a bounding box, you can declare it manually using `settingBounds(_:)`.
    ///
    /// - Parameters:
    ///   - path: The file path to the 3D model to be imported. Paths are resolved relative to the .scad file if not absolute.
    public init(path: String) {
        self.path = (path as NSString).expandingTildeInPath
    }

    func boundary(in environment: EnvironmentValues) -> Bounds {
        .empty // We don't know this; the import is done by OpenSCAD
    }

    let moduleName = "import"
    var moduleParameters: CodeFragment.Parameters {
        ["file": path]
    }
    let supportsPreviewConvexity = true
}
