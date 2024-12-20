import Foundation

public extension Geometry3D {
    /// Apply a color to the geometry.
    ///
    /// - Parameter color: The `Color` instance to apply.
    /// - Returns: A new colored geometry instance.
    func colored(_ color: Color) -> any Geometry3D {
        ApplyColor(body: self, color: color)
    }

    /// Apply a color with transparency to the geometry.
    ///
    /// - Parameters:
    ///   - color: The `Color` instance to apply.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A new colored geometry instance with adjusted transparency.
    func colored(_ color: Color, alpha: Double) -> any Geometry3D {
        colored(color.withAlphaComponent(alpha))
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        colored(.init(red: red, green: green, blue: blue, alpha: alpha))
    }
}

