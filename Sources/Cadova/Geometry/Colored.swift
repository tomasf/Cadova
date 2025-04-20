import Foundation

public extension Geometry3D {
    /// Apply a color to the geometry.
    ///
    /// - Parameter color: The `Color` instance to apply.
    /// - Returns: A new colored geometry instance.
    func colored(_ color: Color) -> any Geometry3D {
        withMaterial(.init(baseColor: color, properties: nil))
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
        withMaterial(.init(
            name: name,
            baseColor: color,
            properties: .metallic(metallicness: metallicness, roughness: roughness)
        ))
    }

    func withMaterial(color: Color, specular: Color, glossiness: Double, name: String? = nil) -> any Geometry3D {
        withMaterial(.init(
            name: name,
            baseColor: color,
            properties: .specular(color: specular, glossiness: glossiness)
        ))
    }

    func withMaterial(_ material: Material) -> any Geometry3D {
        return GeometryExpressionTransformer(body: self) {
            .tag($0, key: .init(material))
        }
        .modifyingResult(MaterialRecord.self) { mapping in
            var mapping = mapping ?? .init()
            mapping.add(material)
            return mapping
        }
    }
}

public extension Material {
    init(name: String? = nil, baseColor: Color, metallicness: Double, roughness: Double) {
        self.init(name: name, baseColor: baseColor, properties: .metallic(metallicness: metallicness, roughness: roughness))
    }

    init(name: String? = nil, baseColor: Color, specularColor: Color, glossiness: Double) {
        self.init(name: name, baseColor: baseColor, properties: .specular(color: specularColor, glossiness: glossiness))
    }

    static let brushedAluminium = Self(name: "Aluminium", baseColor: Color(0.482, 0.482, 0.482), metallicness: 1.0, roughness: 0.4)

    static let glass = Self(name: "Glass", baseColor: Color(0.3, 0.5, 0.3, 0.01), metallicness: 0.9, roughness: 0.05)
    static let copper = Self(name: "Copper", baseColor: Color(0.71, 0.41, 0.24), metallicness: 1.0, roughness: 0.15)

    static let steel = Self(name: "Steel", baseColor: Color(0.37, 0.38, 0.39), metallicness: 0.99, roughness: 0.145)

    static let visualizedPlane = Self(name: "Plane", baseColor: Color(0.3, 0.3, 0.5, 0.2), metallicness: 0.5, roughness: 0.2)
}
