import Foundation

public extension Geometry3D {
    /// Apply a color to the geometry.
    ///
    /// - Parameter color: The `Color` instance to apply.
    /// - Returns: A new colored geometry instance.
    func colored(_ color: Color) -> any Geometry3D {
        ApplyMaterial(body: self, material: .init(baseColor: color, properties: nil))
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

public extension Geometry3D {
    func withMaterial(color: Color, metallicness: Double, roughness: Double, name: String? = nil) -> any Geometry3D {
        ApplyMaterial(body: self, material: .init(baseColor: color, name: name, properties: .metallic(metallicness: metallicness, roughness: roughness)))
    }

    func withMaterial(color: Color, specular: Color, glossiness: Double, name: String? = nil) -> any Geometry3D {
        ApplyMaterial(body: self, material: .init(baseColor: color, name: name, properties: .specular(color: specular, glossiness: glossiness)))
    }
}
