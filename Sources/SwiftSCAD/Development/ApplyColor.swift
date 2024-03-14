import Foundation

internal extension Color {
    var invocation: Invocation {
        let params: [String: any SCADValue]

        switch self {
        case .components (let red, let green, let blue, let alpha):
            params = ["c": [red, green, blue, alpha]]

        case .named (let name, let alpha):
            params = ["c": name.rawValue, "alpha": alpha]
        }

        return Invocation(name: "color", parameters: params)
    }
}

struct ApplyColor2D: WrappedGeometry2D {
    let color: Color
    let body: any Geometry2D
    var invocation: Invocation? { color.invocation }
}

struct ApplyColor3D: WrappedGeometry3D {
    let color: Color
    let body: any Geometry3D
    var invocation: Invocation? { color.invocation }
}

extension Geometry2D {
    func colored(_ color: Color) -> any Geometry2D {
        ApplyColor2D(color: color, body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - name: One of the standard colors. See [the OpenSCAD docs](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Transformations#color) for more info.
    ///   - alpha: The alpha value of the color, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    public func colored(_ name: Color.Name, alpha: Double = 1) -> any Geometry2D {
        ApplyColor2D(color: .named(name, alpha: alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    public func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry2D {
        ApplyColor2D(color: .components(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}

extension Geometry3D {
    func colored(_ color: Color) -> any Geometry3D {
        ApplyColor3D(color: color, body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - name: One of the standard colors. See [the OpenSCAD docs](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Transformations#color) for more info.
    ///   - alpha: The alpha value of the color, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    public func colored(_ name: Color.Name, alpha: Double = 1) -> any Geometry3D {
        ApplyColor3D(color: .named(name, alpha: alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    public func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        ApplyColor3D(color: .components(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}
