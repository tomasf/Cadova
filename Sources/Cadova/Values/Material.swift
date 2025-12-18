import Foundation
import Manifold3D

/// Describes the appearance of a 3D shape using basic color and optional physically based rendering (PBR) properties using
/// roughness/metallicness. `Material` is used to describe material appearance information saved to 3MF. It supports simple
/// flat colors or more advanced materials like metals and matte surfaces using roughness-based PBR.
///
/// Materials can optionally include a `name`, which is stored in the 3MF file and may assist in debugging.
///
public struct Material: Hashable, Sendable, Codable {
    let name: String?
    let baseColor: Color
    let physicalProperties: PhysicalProperties?

    /// Creates a new material.
    ///
    /// - Parameters:
    ///   - name: An optional name for the material.
    ///   - baseColor: The base color to apply to the material.
    ///   - properties: Optional PBR properties using roughness/metallicness.
    ///
    public init(name: String? = nil, baseColor: Color, properties: PhysicalProperties? = nil) {
        self.name = name
        self.baseColor = baseColor
        self.physicalProperties = properties
    }

    /// Physically based rendering (PBR) properties using the metallic/roughness model.
    ///
    /// These properties define how a material interacts with light, allowing you to create
    /// realistic metals, plastics, and other surface types.
    ///
    public struct PhysicalProperties: Hashable, Sendable, Codable {
        /// How metallic the surface appears, from 0 (non-metallic) to 1 (fully metallic).
        let metallicness: Double

        /// How rough the surface appears, from 0 (smooth and reflective) to 1 (fully matte).
        let roughness: Double

        /// Creates PBR properties using a metallic/roughness model.
        ///
        /// - Parameters:
        ///   - metallicness: A value between 0 (non-metallic) and 1 (fully metallic).
        ///   - roughness: A value between 0 (smooth and reflective) and 1 (fully matte).
        ///
        init(metallicness: Double, roughness: Double) {
            self.metallicness = metallicness
            self.roughness = roughness
        }
    }

    /// Creates a plain material with the given base color and optional transparency.
    ///
    /// - Parameters:
    ///   - color: The base color to use.
    ///   - alpha: Optional alpha value. If `nil`, the alpha from `color` is preserved.
    /// - Returns: A basic material without any PBR effects.
    ///
    public static func plain(_ color: Color, alpha: Double? = nil) -> Material {
        return .init(baseColor: color.with(alpha: alpha ?? color.alpha))
    }
}

public extension Material {
    /// Creates a physically-based material using the metallic/roughness model.
    ///
    /// - Parameters:
    ///   - name: An optional name for the material.
    ///   - baseColor: The base color of the material.
    ///   - metallicness: A value between 0 (non-metallic) and 1 (fully metallic).
    ///   - roughness: A value between 0 (smooth and reflective) and 1 (fully matte).
    ///
    init(name: String? = nil, baseColor: Color, metallicness: Double, roughness: Double) {
        self.init(name: name, baseColor: baseColor, properties: .init(metallicness: metallicness, roughness: roughness))
    }
}
