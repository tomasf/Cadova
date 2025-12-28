import Foundation

/// A value used to identify a named part in the 3MF output.
///
/// Parts allow you to group geometry into separate objects in the exported file.
/// Create a part once with its properties, then use it to mark geometry throughout your model.
///
/// ```swift
/// let insert = Part("Metal Insert", material: .steel)
///
/// Box(10)
///     .inPart(insert)
/// ```
///
/// All geometry marked with the same `Part` instance is collected into a single part in the output.
/// The part's name appears in the 3MF file and can be used by slicers to identify and configure
/// the part separately.
///
/// - Multiple assignments:
///   - Geometry can be assigned to a part multiple times. All assignments using the same `Part`
///     instance are merged together.
///
/// - Part semantics:
///   - The ``semantic`` property indicates the role of the part (e.g., `.solid` for printable
///     geometry, `.visual` for reference-only display).
///
public struct Part: Sendable {
    internal let id: UUID

    /// The name of the part as it appears in the 3MF file.
    public let name: String

    /// The semantic role of this part.
    public let semantic: PartSemantic

    /// The default material applied to geometry in this part that doesn't specify its own material.
    ///
    /// Geometry can override this default using the `colored()` modifier.
    public let defaultMaterial: Material

    /// Creates a new part with a unique identity.
    ///
    /// Each call to this initializer creates a distinct part, even if the name is the same.
    /// Use the same `Part` instance to group geometry together.
    ///
    /// - Parameters:
    ///   - name: The name of the part as it appears in the 3MF file.
    ///   - semantic: The semantic role of this part. Defaults to `.solid`.
    ///   - material: The default material for geometry that doesn't specify its own.
    ///     Geometry can override this using the `colored()` modifier. Defaults to white.
    ///
    public init(_ name: String, semantic: PartSemantic = .solid, material: Material) {
        self.id = UUID()
        self.name = name
        self.semantic = semantic
        self.defaultMaterial = material
    }

    /// Creates a new part with a plain color as the default material.
    ///
    /// Geometry in this part will use the specified color unless it specifies its own
    /// material using the `colored()` modifier.
    ///
    /// - Parameters:
    ///   - name: The name of the part as it appears in the 3MF file.
    ///   - semantic: The semantic role of this part. Defaults to `.solid`.
    ///   - color: The default color for geometry that doesn't specify its own material.
    ///
    public init(_ name: String, semantic: PartSemantic = .solid, color: Color = .white) {
        self.init(name, semantic: semantic, material: .plain(color))
    }

    /// Creates a new part with a physically-based default material.
    ///
    /// Geometry in this part will use the specified PBR material unless it specifies its own
    /// material using the `colored()` modifier.
    ///
    /// - Parameters:
    ///   - name: The name of the part as it appears in the 3MF file.
    ///   - semantic: The semantic role of this part. Defaults to `.solid`.
    ///   - color: The default base color for geometry that doesn't specify its own material.
    ///   - metallicness: A value between 0 (non-metallic) and 1 (fully metallic).
    ///   - roughness: A value between 0 (smooth and reflective) and 1 (fully matte).
    ///
    public init(_ name: String, semantic: PartSemantic = .solid, color: Color, metallicness: Double, roughness: Double) {
        self.init(name, semantic: semantic, material: .init(baseColor: color, metallicness: metallicness, roughness: roughness))
    }
}

extension Part: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

    public static func ==(lhs: Part, rhs: Part) -> Bool {
        lhs.id == rhs.id
    }
}

extension Part: Codable {}

internal extension Part {
    static let highlighted = Part("Highlighted", semantic: .visual, material: .highlightedGeometry)
    static let background = Part("Background", semantic: .context, material: .backgroundGeometry)

    // Visualization parts
    static let visualizedPlane = Part("Visualized Plane", semantic: .visual)
    static let visualizedBoundingBox = Part("Visualized Bounding Box", semantic: .visual)
    static let visualizedAxes = Part("Visualized Axes", semantic: .visual)
    static let visualizedPath = Part("Visualized Path", semantic: .visual)
    static let visualizedDirection = Part("Visualized Direction", semantic: .visual)
    static let visualizedLoftLayers = Part("Visualized Loft Layers", semantic: .visual)
    static let visualizedRuler = Part("Visualized Ruler", semantic: .visual)
}

internal struct PartCatalog: ResultElement {
    var parts: [Part: [D3.BuildResult]]

    init(parts: [Part: [D3.BuildResult]]) {
        self.parts = parts
    }

    init() {
        self.init(parts: [:])
    }

    init(combining catalogs: [PartCatalog]) {
        self.init(parts: catalogs.reduce(into: [:]) { result, catalog in
            result.merge(catalog.parts, uniquingKeysWith: +)
        })
    }

    mutating func add(result: D3.BuildResult, to part: Part) {
        parts[part, default: []].append(result)
    }

    mutating func detach(_ part: Part) -> D3.BuildResult? {
        guard let results = parts.removeValue(forKey: part) else {
            return nil
        }
        return D3.BuildResult(combining: results, operationType: .union)
    }

    var mergedOutputs: [Part: D3.BuildResult] {
        parts.mapValues { outputs in
            D3.BuildResult(combining: outputs, operationType: .union)
        }
    }

    func modifyingNodes(_ modifier: (D3.Node) -> D3.Node) -> Self {
        .init(parts: parts.mapValues {
            $0.map { $0.replacing(node: modifier($0.node)) }
        })
    }

    func applyingTransform(_ transform: Transform3D) -> Self {
        guard !parts.isEmpty else { return self }
        return modifyingNodes { .transform($0, transform: transform) }
    }
}
