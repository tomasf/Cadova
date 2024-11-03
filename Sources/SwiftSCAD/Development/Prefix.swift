import Foundation

fileprivate struct Prefix<Geometry> {
    let isImmaterial: Bool
    let prefix: String
    let body: Geometry

    init(prefix: String, isImmaterial: Bool = false, body: Geometry) {
        self.prefix = prefix
        self.isImmaterial = isImmaterial
        self.body = body
    }
}

extension Prefix<any Geometry2D>: Geometry2D {
    func evaluated(in environment: Environment) -> Output2D {
        let child = body.evaluated(in: environment)
        return .init(
            codeFragment: .init(prefix: prefix, body: child.codeFragment),
            boundary: isImmaterial ? .empty : child.boundary,
            elements: child.elements
        )
    }
}

extension Prefix<any Geometry3D>: Geometry3D {
    func evaluated(in environment: Environment) -> Output3D {
        let child = body.evaluated(in: environment)
        return .init(
            codeFragment: .init(prefix: prefix, body: child.codeFragment),
            boundary: isImmaterial ? .empty : child.boundary,
            elements: child.elements
        )
    }
}


public extension Geometry2D {
    /// Highlight this geometry
    ///
    /// Highlighting is for debugging and is not visible in final renderings. This is equivalent to the `#` modifier in OpenSCAD.

    func highlighted() -> any Geometry2D {
        Prefix(prefix: "#", body: self)
    }

    /// Display only this geometry
    ///
    /// Use this geometry as the root, ignoring anything outside it. This is equivalent to the `!` modifier in OpenSCAD.

    func only() -> any Geometry2D {
        Prefix(prefix: "!", body: self)
    }

    /// Display this geometry as background
    ///
    /// Background is drawn transparently, isn't part of the actual geometry, and is ignored in final renderings. This is equivalent to the `%` modifier in OpenSCAD.

    func background() -> any Geometry2D {
        Prefix(prefix: "%", isImmaterial: true, body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry2D {
        Prefix(prefix: "*", isImmaterial: true, body: self)
    }

    /// Hide this geometry
    ///
    /// Ignore the visual aspect of this geometry, but keep its bounding box. This, for example, hides an item in a stack, but still takes up space.

    func hidden() -> any Geometry2D {
        Prefix(prefix: "*", isImmaterial: false, body: self)
    }
}

public extension Geometry3D {
    /// Highlight this geometry
    ///
    /// Highlighting is for debugging and is not visible in final renderings. This is equivalent to the `#` modifier in OpenSCAD.

    func highlighted() -> any Geometry3D {
        Prefix(prefix: "#", body: self)
    }

    /// Display only this geometry
    ///
    /// Use this geometry as the root, ignoring anything outside it. This is equivalent to the `!` modifier in OpenSCAD.

    func only() -> any Geometry3D {
        Prefix(prefix: "!", body: self)
    }

    /// Display this geometry as background
    ///
    /// Background is drawn transparently, isn't part of the actual geometry, and is ignored in final renderings. This is equivalent to the `%` modifier in OpenSCAD.

    func background() -> any Geometry3D {
        Prefix(prefix: "%", isImmaterial: true, body: self)
    }

    /// Disable this geometry
    ///
    /// Ignore this geometry as if it didn't exist. This is equivalent to the `*` modifier in OpenSCAD.

    func disabled() -> any Geometry3D {
        Prefix(prefix: "*", isImmaterial: true, body: self)
    }

    /// Hide this geometry
    ///
    /// Ignore the visual aspect of this geometry, but keep its bounding box. This, for example, hides an item in a stack, but still takes up space.

    func hidden() -> any Geometry3D {
        Prefix(prefix: "*", isImmaterial: false, body: self)
    }
}
