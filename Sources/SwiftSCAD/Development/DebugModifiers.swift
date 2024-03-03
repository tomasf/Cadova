import Foundation

struct Prefix3D: Geometry3D {
    let prefix: String
    let body: any Geometry3D

    func scadString(in environment: Environment) -> String {
        return prefix + body.scadString(in: environment)
    }
}

struct Prefix2D: Geometry2D {
    let prefix: String
    let body: any Geometry2D

    func scadString(in environment: Environment) -> String {
        return prefix + body.scadString(in: environment)
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
        Prefix2D(prefix: "%", body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry2D {
        Prefix2D(prefix: "*", body: self)
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
        Prefix3D(prefix: "%", body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry3D {
        Prefix3D(prefix: "*", body: self)
    }
}
