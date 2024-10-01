import Foundation

struct Prefix2D: WrappedGeometry2D {
    let isImmaterial: Bool
    let prefix: String
    let body: any Geometry2D

    init(prefix: String, isImmaterial: Bool = false, body: any Geometry2D) {
        self.prefix = prefix
        self.isImmaterial = isImmaterial
        self.body = body
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(prefix: prefix, body: body.codeFragment(in: environment))
    }

    func boundary(in environment: Environment) -> Bounds {
        isImmaterial ? .empty : body.boundary(in: environment)
    }
}

struct Prefix3D: WrappedGeometry3D {
    let isImmaterial: Bool
    let prefix: String
    let body: any Geometry3D

    init(prefix: String, isImmaterial: Bool = false, body: any Geometry3D) {
        self.prefix = prefix
        self.isImmaterial = isImmaterial
        self.body = body
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(prefix: prefix, body: body.codeFragment(in: environment))
    }

    func boundary(in environment: Environment) -> Bounds {
        isImmaterial ? .empty : body.boundary(in: environment)
    }
}

public extension Geometry2D {
    /// Highlight this geometry
    ///
    /// Highlighting is for debugging and is not visible in final renderings. This is equivalent to the `#` modifier in OpenSCAD.

    func highlighted() -> any Geometry2D {
        Prefix2D(prefix: "#", body: self)
    }

    /// Display only this geometry
    ///
    /// Use this geometry as the root, ignoring anything outside it. This is equivalent to the `!` modifier in OpenSCAD.

    func only() -> any Geometry2D {
        Prefix2D(prefix: "!", body: self)
    }

    /// Display this geometry as background
    ///
    /// Background is drawn transparently, isn't part of the actual geometry, and is ignored in final renderings. This is equivalent to the `%` modifier in OpenSCAD.

    func background() -> any Geometry2D {
        Prefix2D(prefix: "%", isImmaterial: true, body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry2D {
        Prefix2D(prefix: "*", isImmaterial: true, body: self)
    }

    /// Hide this geometry
    ///
    /// Ignore the visual aspect of this geometry, but keep its bounding box. This, for example, hides an item in a stack, but still takes up space.

    func hidden() -> any Geometry2D {
        Prefix2D(prefix: "*", isImmaterial: false, body: self)
    }
}

public extension Geometry3D {
    /// Highlight this geometry
    ///
    /// Highlighting is for debugging and is not visible in final renderings. This is equivalent to the `#` modifier in OpenSCAD.

    func highlighted() -> any Geometry3D {
        Prefix3D(prefix: "#", body: self)
    }

    /// Display only this geometry
    ///
    /// Use this geometry as the root, ignoring anything outside it. This is equivalent to the `!` modifier in OpenSCAD.

    func only() -> any Geometry3D {
        Prefix3D(prefix: "!", body: self)
    }

    /// Display this geometry as background
    ///
    /// Background is drawn transparently, isn't part of the actual geometry, and is ignored in final renderings. This is equivalent to the `%` modifier in OpenSCAD.

    func background() -> any Geometry3D {
        Prefix3D(prefix: "%", isImmaterial: true, body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry3D {
        Prefix3D(prefix: "*", isImmaterial: true, body: self)
    }

    /// Hide this geometry
    ///
    /// Ignore the visual aspect of this geometry, but keep its bounding box. This, for example, hides an item in a stack, but still takes up space.

    func hidden() -> any Geometry3D {
        Prefix3D(prefix: "*", isImmaterial: false, body: self)
    }
}
