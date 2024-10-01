import Foundation

struct ApplyColor2D: WrappedGeometry2D {
    let color: Color
    let body: any Geometry2D

    let moduleName: String? = "color"
    var moduleParameters: CodeFragment.Parameters { color.moduleParameters }
}

struct ApplyColor3D: WrappedGeometry3D {
    let color: Color
    let body: any Geometry3D

    let moduleName: String? = "color"
    var moduleParameters: CodeFragment.Parameters { color.moduleParameters }
}

public extension Geometry2D {
    func colored(_ color: Color) -> any Geometry2D {
        ApplyColor2D(color: color, body: self)
    }

    func colored(_ color: Color, alpha: Double) -> any Geometry2D {
        ApplyColor2D(color: color.withAlphaComponent(alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry2D {
        ApplyColor2D(color: .init(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}

public extension Geometry3D {
    func colored(_ color: Color) -> any Geometry3D {
        ApplyColor3D(color: color, body: self)
    }

    func colored(_ color: Color, alpha: Double) -> any Geometry3D {
        ApplyColor3D(color: color.withAlphaComponent(alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        ApplyColor3D(color: .init(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}
