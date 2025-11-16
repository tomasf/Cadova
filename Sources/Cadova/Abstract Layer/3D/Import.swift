import Foundation
import ThreeMF
import Manifold3D

/// Imports geometry from an external 3MF file.
///
/// Use `Import` to bring in geometry from existing 3MF models, either in full or by selecting specific parts.
/// This is useful for reusing designs, integrating CAD files, or combining Cadova-generated models with external assets.
///
/// ```swift
/// Import(model: "fixtures/handle.3mf")
/// ```
///
/// You can also import individual parts by object name or part number:
///
/// ```swift
/// Import(
///     model: "fixtures/handle.3mf",
///     parts: [
///         .name("Knob"),
///         .partNumber("1234-XYZ")
///     ]
/// )
/// ```
///
public struct Import: Shape3D {
    private let url: URL
    private let parts: [PartIdentifier]?

    /// Creates a new imported shape from a 3MF file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the 3MF model.
    ///   - parts: An optional list of part identifiers to import. If omitted, all parts are imported.
    ///
    public init(model url: URL, parts: [PartIdentifier]? = nil) {
        self.url = url
        self.parts = parts
    }

    /// Creates a new imported shape from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the 3MF model. Can be relative or absolute.
    ///   - parts: An optional list of part identifiers to import. If omitted, all parts are imported.
    ///
    public init(model path: String, parts: [PartIdentifier]? = nil) {
        self.init(
            model: URL(expandingFilePath: path, extension: nil, relativeTo: nil),
            parts: parts
        )
    }

    /// Identifies a specific part of a 3MF model to import.
    public enum PartIdentifier: CacheKey {
        /// Matches an item by the name parameter of its referenced object.
        case name (String)

        /// Matches an item by its `partnumber` attribute.
        case partNumber (String)
    }

    public enum Error: Swift.Error {
        /// A requested part was not found in the model.
        case missingPart (Import.PartIdentifier)

        var localizedDescription: String {
            switch self {
            case .missingPart (let partIdentifier):
                "A part matching \(partIdentifier) was not found in the model."
            }
        }
    }

    public var body: any Geometry3D {
        CachedNode(name: "import", parameters: url, parts) { _, _ in
            let loadedModel = try await ModelLoader(url: url).load()
            let loadedItems = try loadedModel.loadedItems(for: parts)
            return D3.Node.boolean(loadedItems.map {
                $0.buildNode(model: loadedModel)
            }, type: .union)
        }
    }
}

internal extension ModelLoader.LoadedModel {
    func loadedItems(for identifiers: [Import.PartIdentifier]?) throws -> [LoadedItem] {
        var remainingItems = items
        guard let identifiers else { return remainingItems }

        return try identifiers.map { identifier in
            guard let itemIndex = remainingItems.firstIndex(where: { $0.matches(identifier) }) else {
                throw Import.Error.missingPart(identifier)
            }
            return remainingItems.remove(at: itemIndex)
        }
    }
}

internal extension ModelLoader.LoadedModel.LoadedItem {
    func matches(_ identifier: Import.PartIdentifier) -> Bool {
        switch identifier {
        case .name (let name): rootObject.name == name
        case .partNumber (let partNumber): item.partNumber == partNumber
        }
    }

    func buildNode(model: ModelLoader.LoadedModel) -> D3.Node {
        .boolean(components.map { $0.buildNode(model: model) }, type: .union)
    }
}

internal extension ModelLoader.LoadedModel.LoadedComponent {
    func buildNode(model: ModelLoader.LoadedModel) -> D3.Node {
        let meshNode = D3.Node.shape(.mesh(MeshData(model.meshes[meshIndex].mesh)))
        return if let transform = cadovaTransform {
            .transform(meshNode, transform: transform)
        } else {
            meshNode
        }
    }

    var cadovaTransform: Transform3D? {
        guard !transforms.isEmpty else { return nil }
        return transforms.map(\.cadovaTransform)
            .reduce(Transform3D.identity) { $0.concatenated(with: $1) }
    }
}

internal extension MeshData {
    init(_ mesh: ThreeMF.Mesh) {
        self.init(
            vertices: mesh.vertices.map { Vector3D($0.x, $0.y, $0.z) },
            faces: mesh.triangles.map { [$0.v1, $0.v2, $0.v3] }
        )
    }
}

internal extension ThreeMF.Matrix3D {
    var cadovaTransform: Transform3D {
        Transform3D([
            [values[0][0], values[1][0], values[2][0], values[3][0]],
            [values[0][1], values[1][1], values[2][1], values[3][1]],
            [values[0][2], values[1][2], values[2][2], values[3][2]],
            [0, 0, 0, 1]
        ])
    }
}
