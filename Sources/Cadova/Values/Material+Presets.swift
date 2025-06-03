import Foundation

public extension Material {
    /// Transparent glass-like material with a slight greenish tint.
    static let glass = Self(name: "Glass", baseColor: Color(0.3, 0.5, 0.3, 0.01), metallicness: 0.9, roughness: 0.05)

    /// Semi-transparent colored glass.
    ///
    /// - Parameter color: The color tint to use.
    /// - Returns: A material that simulates stained glass.
    static func stainedGlass(_ color: Color) -> Self {
        Self(name: "Stained Glass", baseColor: color.with(alpha: 0.6), metallicness: 0.95, roughness: 0.25)
    }

    /// Very transparent glass with a subtle colored cast.
    ///
    /// - Parameter color: The hue to influence the cast.
    /// - Returns: A subtly tinted transparent glass material.
    static func glass(cast color: Color) -> Self {
        Self(name: "Glass", baseColor: color.with(saturation: 0.4, brightness: 0.5, alpha: 0.01), metallicness: 0.9, roughness: 0.05)
    }

    /// Simulates polished copper with a reddish metallic tone.
    static let copper = Self(name: "Copper", baseColor: Color(0.71, 0.41, 0.24), metallicness: 1.0, roughness: 0.15)

    /// Simulates industrial-grade steel with high reflectivity.
    static let steel = Self(name: "Steel", baseColor: Color(0.37, 0.38, 0.39), metallicness: 0.99, roughness: 0.145)

    /// Simulates brushed aluminum with mid-level roughness.
    static let brushedAluminium = Self(name: "Aluminium", baseColor: Color(0.482, 0.482, 0.482), metallicness: 1.0, roughness: 0.5)

    /// Highly reflective chrome-like surface.
    static let chrome = Self(name: "Chrome", baseColor: .white, metallicness: 1.0, roughness: 0.03)

    /// Simulates smooth, glossy plastic.
    ///
    /// - Parameter color: The base color of the plastic.
    /// - Returns: A glossy plastic material.
    static func glossyPlastic(_ color: Color) -> Self {
        Self(name: "Smooth Plastic", baseColor: color, metallicness: 0, roughness: 0.2)
    }

    /// Simulates matte-finished plastic.
    ///
    /// - Parameter color: The base color of the plastic.
    /// - Returns: A matte plastic material.
    static func mattePlastic(_ color: Color) -> Self {
        Self(name: "Matte Plastic", baseColor: color, metallicness: 0, roughness: 0.7)
    }

    /// Simulates unfinished or natural wood.
    static let wood = Self(name: "Bare Wood", baseColor: Color(0.5, 0.35, 0.2), metallicness: 0, roughness: 0.8)
}

internal extension Material {
    static let visualizedPlane = Self(name: "Plane", baseColor: Color(0.3, 0.3, 0.5, 0.2), metallicness: 0.5, roughness: 0.2)

    static let highightedGeometry = Self.plain(.red, alpha: 0.4)
    static let backgroundGeometry = Self.plain(.darkGray, alpha: 0.3)
}
