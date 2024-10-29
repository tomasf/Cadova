import Foundation

struct ApplyColor<Geometry> {
    let color: Color
    let body: Geometry

    let moduleName: String? = "color"
    var moduleParameters: CodeFragment.Parameters { color.moduleParameters }
}

extension ApplyColor<any Geometry2D>: Geometry2D, WrappedGeometry2D {}
extension ApplyColor<any Geometry3D>: Geometry3D, WrappedGeometry3D {}


public extension Geometry2D {
    func colored(_ color: Color) -> any Geometry2D {
        ApplyColor(color: color, body: self)
    }

    func colored(_ color: Color, alpha: Double) -> any Geometry2D {
        ApplyColor(color: color.withAlphaComponent(alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry2D {
        ApplyColor(color: .init(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}

public extension Geometry3D {
    func colored(_ color: Color) -> any Geometry3D {
        ApplyColor(color: color, body: self)
    }

    func colored(_ color: Color, alpha: Double) -> any Geometry3D {
        ApplyColor(color: color.withAlphaComponent(alpha), body: self)
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        ApplyColor(color: .init(red: red, green: green, blue: blue, alpha: alpha), body: self)
    }
}
