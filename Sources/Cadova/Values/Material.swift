import Foundation
import Manifold3D

/// Describes the appearance of a 3D shape using basic color and optional physically
/// based rendering (PBR) properties. `Material` is used to describe material appearance
/// information saved to 3MF. It supports simple flat colors or more advanced materials
/// like metals and glossy surfaces using PBR extensions.
///
/// Materials can optionally include a `name`, which is stored in the 3MF file and may assist in debugging or future workflows.
///
public struct Material: Hashable, Sendable, Codable {
    let name: String?
    let baseColor: Color
    let properties: Properties?

    /// Creates a new material.
    ///
    /// - Parameters:
    ///   - name: An optional name for the material.
    ///   - baseColor: The base color to apply to the material.
    ///   - properties: Optional PBR properties such as metallic or specular reflection.
    public init(name: String? = nil, baseColor: Color, properties: Properties? = nil) {
        self.name = name
        self.baseColor = baseColor
        self.properties = properties
    }

    /// Additional physical rendering properties for a material.
    ///
    /// These allow customization of how the material reflects light, including metallic surfaces
    /// and glossy or specular highlights.
    public enum Properties: Hashable, Sendable, Codable {
        /// A metallic material using roughness-based shading.
        ///
        /// - Parameters:
        ///   - metallicness: A value between 0 (non-metallic) and 1 (fully metallic).
        ///   - roughness: A value between 0 (smooth, mirror-like) and 1 (rough, matte).
        case metallic(metallicness: Double, roughness: Double)

        /// A specular material with colored highlights and glossiness control.
        ///
        /// - Parameters:
        ///   - color: The color of the specular reflection.
        ///   - glossiness: A value between 0 (dull) and 1 (highly glossy).
        case specular(color: Color, glossiness: Double)
    }

    /// Creates a plain material with the given base color and optional transparency.
    ///
    /// - Parameters:
    ///   - color: The base color to use.
    ///   - alpha: Optional alpha value. If `nil`, the alpha from `color` is preserved.
    /// - Returns: A basic material without any PBR effects.
    public static func plain(_ color: Color, alpha: Double? = nil) -> Material {
        return .init(baseColor: color.with(alpha: alpha ?? color.alpha))
    }
}

public extension Material {
    /// Creates a metallic material with roughness-based shading.
    ///
    /// - Parameters:
    ///   - name: An optional name for the material.
    ///   - baseColor: The base color of the material.
    ///   - metallicness: A value between 0 (non-metallic) and 1 (fully metallic).
    ///   - roughness: A value between 0 (smooth, mirror-like) and 1 (rough, matte).
    ///
    init(name: String? = nil, baseColor: Color, metallicness: Double, roughness: Double) {
        self.init(name: name, baseColor: baseColor, properties: .metallic(metallicness: metallicness, roughness: roughness))
    }

    /// Creates a specular material with colored highlights and glossiness control.
    ///
    /// - Parameters:
    ///   - name: An optional name for the material.
    ///   - baseColor: The base color of the material.
    ///   - specularColor: The color of the specular highlights.
    ///   - glossiness: A value between 0 (dull) and 1 (highly glossy).
    ///
    init(name: String? = nil, baseColor: Color, specularColor: Color, glossiness: Double) {
        self.init(name: name, baseColor: baseColor, properties: .specular(color: specularColor, glossiness: glossiness))
    }
}
