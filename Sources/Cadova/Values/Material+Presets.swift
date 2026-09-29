import Foundation

public extension Material {
    // MARK: - Glass

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

    /// Milky, translucent glass with a diffusing, sandblasted surface.
    static let frostedGlass = Self(name: "Frosted Glass", baseColor: Color(0.95, 0.95, 0.95, 0.8), metallicness: 0, roughness: 0.5)

    // MARK: - Precious metals

    /// Polished yellow gold.
    static let gold = Self(name: "Gold", baseColor: Color(1.0, 0.78, 0.3), metallicness: 1.0, roughness: 0.12)

    /// Polished rose gold, a pinkish gold–copper alloy.
    static let roseGold = Self(name: "Rose Gold", baseColor: Color(1.0, 0.76, 0.62), metallicness: 1.0, roughness: 0.12)

    /// Polished silver.
    static let silver = Self(name: "Silver", baseColor: Color(0.99, 0.98, 0.97), metallicness: 1.0, roughness: 0.1)

    /// Polished platinum, a slightly darker and warmer white metal than silver.
    static let platinum = Self(name: "Platinum", baseColor: Color(0.85, 0.84, 0.82), metallicness: 1.0, roughness: 0.15)

    // MARK: - Copper alloys

    /// Simulates polished copper with a reddish metallic tone.
    static let copper = Self(name: "Copper", baseColor: Color(0.96, 0.6, 0.4), metallicness: 1.0, roughness: 0.15)

    /// Polished brass, a yellow copper–zinc alloy.
    static let brass = Self(name: "Brass", baseColor: Color(0.91, 0.78, 0.42), metallicness: 1.0, roughness: 0.2)

    /// Satin-finished bronze, a warm copper–tin alloy.
    static let bronze = Self(name: "Bronze", baseColor: Color(0.8, 0.58, 0.35), metallicness: 1.0, roughness: 0.3)

    // MARK: - Iron and steel

    /// Simulates industrial-grade steel with high reflectivity.
    static let steel = Self(name: "Steel", baseColor: Color(0.56, 0.57, 0.58), metallicness: 1.0, roughness: 0.3)

    /// Brushed stainless steel, as on sinks and kitchen appliances.
    static let stainlessSteel = Self(name: "Stainless Steel", baseColor: Color(0.78, 0.78, 0.78), metallicness: 1.0, roughness: 0.25)

    /// Zinc-coated steel with a dull, matte sheen, as on buckets and sheet metal.
    static let galvanizedSteel = Self(name: "Galvanized Steel", baseColor: Color(0.7, 0.73, 0.75), metallicness: 1.0, roughness: 0.45)

    /// Dark, seasoned cast iron, as on skillets.
    static let castIron = Self(name: "Cast Iron", baseColor: Color(0.35, 0.34, 0.33), metallicness: 1.0, roughness: 0.6)

    /// Highly reflective chrome-like surface.
    static let chrome = Self(name: "Chrome", baseColor: .white, metallicness: 1.0, roughness: 0.03)

    // MARK: - Other metals

    /// Simulates brushed aluminum with mid-level roughness.
    static let brushedAluminium = Self(name: "Aluminium", baseColor: Color(0.8, 0.8, 0.81), metallicness: 1.0, roughness: 0.45)

    /// Colored anodized aluminium, as on carabiners and flashlights.
    ///
    /// - Parameter color: The dye color of the anodized layer.
    /// - Returns: A satin, colored metal material.
    static func anodizedAluminium(_ color: Color) -> Self {
        Self(name: "Anodized Aluminium", baseColor: color, metallicness: 1.0, roughness: 0.35)
    }

    /// Bare titanium with a light, slightly warm gray tone.
    static let titanium = Self(name: "Titanium", baseColor: Color(0.62, 0.6, 0.57), metallicness: 1.0, roughness: 0.35)

    /// Pewter, a soft gray tin alloy with a dull sheen.
    static let pewter = Self(name: "Pewter", baseColor: Color(0.6, 0.61, 0.62), metallicness: 1.0, roughness: 0.45)

    /// Glossy metallic automotive paint.
    ///
    /// - Parameter color: The color of the paint.
    /// - Returns: A glossy material with a partial metallic sheen.
    static func metallicPaint(_ color: Color) -> Self {
        Self(name: "Metallic Paint", baseColor: color, metallicness: 0.5, roughness: 0.25)
    }

    // MARK: - Corrosion

    /// Orange-brown iron oxide, as on weathered steel.
    static let rust = Self(name: "Rust", baseColor: Color(0.66, 0.33, 0.14), metallicness: 0, roughness: 0.9)

    /// The green patina that forms on weathered copper, brass and bronze.
    static let verdigris = Self(name: "Verdigris", baseColor: Color(0.42, 0.58, 0.5), metallicness: 0, roughness: 0.8)

    // MARK: - Plastic and rubber

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

    /// Black rubber, as on tires, boots and gaskets.
    static let rubber = Self(name: "Rubber", baseColor: Color(0.16, 0.16, 0.16), metallicness: 0, roughness: 0.85)

    // MARK: - Ceramics and stone

    /// Glazed white porcelain.
    static let porcelain = Self(name: "Porcelain", baseColor: Color(0.88, 0.88, 0.87), metallicness: 0, roughness: 0.05)

    /// Unglazed, fired orange-red clay, as on flower pots.
    static let terracotta = Self(name: "Terracotta", baseColor: Color(0.72, 0.4, 0.27), metallicness: 0, roughness: 0.85)

    /// Red clay brick.
    static let brick = Self(name: "Brick", baseColor: Color(0.62, 0.3, 0.22), metallicness: 0, roughness: 0.9)

    /// Polished white marble.
    static let marble = Self(name: "Marble", baseColor: Color(0.92, 0.9, 0.88), metallicness: 0, roughness: 0.1)

    /// Plain gray concrete.
    static let concrete = Self(name: "Concrete", baseColor: Color(0.62, 0.61, 0.58), metallicness: 0, roughness: 0.9)

    /// Buff-colored sandstone.
    static let sandstone = Self(name: "Sandstone", baseColor: Color(0.8, 0.7, 0.52), metallicness: 0, roughness: 0.9)

    /// Dark blue-gray slate.
    static let slate = Self(name: "Slate", baseColor: Color(0.32, 0.34, 0.36), metallicness: 0, roughness: 0.7)

    // MARK: - Wood

    /// Simulates unfinished or natural wood.
    static let wood = Self(name: "Bare Wood", baseColor: Color(0.5, 0.35, 0.2), metallicness: 0, roughness: 0.8)

    /// Light pale wood, as on birch plywood.
    static let birch = Self(name: "Birch", baseColor: Color(0.87, 0.75, 0.58), metallicness: 0, roughness: 0.7)

    /// Medium golden-brown oak.
    static let oak = Self(name: "Oak", baseColor: Color(0.68, 0.53, 0.37), metallicness: 0, roughness: 0.6)

    /// Dark reddish-brown walnut.
    static let walnut = Self(name: "Walnut", baseColor: Color(0.42, 0.25, 0.15), metallicness: 0, roughness: 0.5)

    /// Cork, as on wine stoppers and pin boards.
    static let cork = Self(name: "Cork", baseColor: Color(0.72, 0.55, 0.38), metallicness: 0, roughness: 0.9)

    // MARK: - Other materials

    /// Brown leather.
    static let leather = Self(name: "Leather", baseColor: Color(0.4, 0.24, 0.14), metallicness: 0, roughness: 0.55)

    /// Off-white bone.
    static let bone = Self(name: "Bone", baseColor: Color(0.9, 0.88, 0.8), metallicness: 0, roughness: 0.6)

    /// White paper.
    static let paper = Self(name: "Paper", baseColor: Color(0.93, 0.93, 0.92), metallicness: 0, roughness: 0.85)

    /// Brown corrugated cardboard.
    static let cardboard = Self(name: "Cardboard", baseColor: Color(0.7, 0.55, 0.38), metallicness: 0, roughness: 0.9)
}

internal extension Material {
    static let highlightedGeometry = Self.plain(.red, alpha: 0.4)
    static let backgroundGeometry = Self.plain(.silver, alpha: 0.6)
}
