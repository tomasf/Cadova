import Foundation

public extension Geometry3D {
    /// Applies a flat color to the geometry.
    ///
    /// This is primarily a visual styling feature, useful when previewing the model or distinguishing parts by color.
    /// The color is also included in the exported 3MF file, though most slicers do not use it for functional
    /// differentiation.
    ///
    /// - Parameter color: The `Color` to apply.
    /// - Returns: A new geometry instance with the color applied.
    /// 
    func colored(_ color: Color) -> any Geometry3D {
        withMaterial(.init(baseColor: color, properties: nil))
    }

    /// Applies a flat color with transparency to the geometry.
    ///
    /// - Parameters:
    ///   - color: The base color.
    ///   - alpha: The alpha component of the color, in the range `0.0...1.0`.
    /// - Returns: A new geometry instance with the color and transparency applied.
    ///
    func colored(_ color: Color, alpha: Double) -> any Geometry3D {
        colored(color.with(alpha: alpha))
    }

    /// Applies a color to the geometry using individual color components.
    ///
    /// - Parameters:
    ///   - red: The red component, from `0.0` to `1.0`.
    ///   - green: The green component, from `0.0` to `1.0`.
    ///   - blue: The blue component, from `0.0` to `1.0`.
    ///   - alpha: The alpha component, from `0.0` to `1.0`. Defaults to `1`.
    /// - Returns: A geometry instance with the given RGBA color applied.
    ///
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        colored(.init(red: red, green: green, blue: blue, alpha: alpha))
    }
}

public extension Geometry3D {
    /// Applies a physically-based material with metallic and roughness values.
    ///
    /// This method is ideal for specifying realistic materials in a viewer context, such as metals or plastics.
    ///
    /// - Parameters:
    ///   - color: The base color of the material.
    ///   - metallicness: The metallic quality, from `0.0` (non-metal) to `1.0` (fully metallic).
    ///   - roughness: The surface roughness, from `0.0` (smooth) to `1.0` (rough).
    ///   - name: An optional name for identifying the material.
    /// - Returns: A new geometry instance with the specified material applied.
    ///
    func withMaterial(color: Color, metallicness: Double, roughness: Double, name: String? = nil) -> any Geometry3D {
        withMaterial(.init(
            name: name,
            baseColor: color,
            properties: .metallic(metallicness: metallicness, roughness: roughness)
        ))
    }

    /// Applies a physically-based material with specular highlights and glossiness.
    ///
    /// This method is ideal for defining materials like glossy plastics or reflective coatings.
    ///
    /// - Parameters:
    ///   - color: The base color of the material.
    ///   - specular: The specular highlight color.
    ///   - glossiness: Glossiness from `0.0` (dull) to `1.0` (shiny).
    ///   - name: An optional name for the material.
    /// - Returns: A new geometry instance with the material applied.
    ///
    func withMaterial(color: Color, specular: Color, glossiness: Double, name: String? = nil) -> any Geometry3D {
        withMaterial(.init(
            name: name,
            baseColor: color,
            properties: .specular(color: specular, glossiness: glossiness)
        ))
    }

    /// Applies a custom `Material` instance to the geometry.
    ///
    /// - Parameter material: The material to apply.
    /// - Returns: A new geometry instance with the material applied.
    ///
    func withMaterial(_ material: Material) -> any Geometry3D {
        GeometryNodeTransformer(body: self) {
            .applyMaterial($0, material: material)
        } environment: { $0.withMaterial(material) }
    }
}
