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

        /// A referenced object could not be resolved.
        case missingObject (ThreeMF.ResourceID)

        var localizedDescription: String {
            switch self {
            case .missingPart (let partIdentifier):
                "A part matching \(partIdentifier) was not found in the model."
            case .missingObject (let id):
                "A referenced object with ID \(id) could not be resolved."
            }
        }
    }

    public var body: any Geometry3D {
        CachedNode(name: "import", parameters: url, parts) { _, _ in
            let model = try PackageReader(url: url).model()
            return try model.node(for: parts)
        }
    }
}

internal extension ThreeMF.Model {
    func node(for parts: [Import.PartIdentifier]?) throws -> D3.Node {
        let nodes = if let partsIDs = parts {
            try partsIDs.map {
                guard let item = firstItem(matching: $0) else {
                    throw Import.Error.missingPart($0)
                }
                return try node(for: item)
            }
        } else {
            try buildItems.map { try node(for: $0) }
        }
        return .boolean(nodes, type: .union)
    }

    func node(for item: ThreeMF.Item) throws -> D3.Node {
        let object = try self.object(for: item.objectID)
        let geometry = try self.node(for: object)

        return if let transform = item.transform {
            .transform(geometry, transform: transform.cadovaTransform)
        } else {
            geometry
        }
    }

    func node(for object: ThreeMF.Object) throws -> D3.Node {
        switch object.content {
        case .mesh (let mesh):
            return .shape(.mesh(.init(mesh)))

        case .components (let components):
            let subnodes = try components.map { component -> D3.Node in
                let subobject = try self.object(for: component.objectID)
                let subgeometry = try self.node(for: subobject)
                return if let transform = component.transform {
                    .transform(subgeometry, transform: transform.cadovaTransform)
                } else {
                    subgeometry
                }
            }
            return .boolean(subnodes, type: .union)
        }
    }

    func firstItem(matching identifier: Import.PartIdentifier) -> ThreeMF.Item? {
        buildItems.first { item in
            switch identifier {
            case let .partNumber (partNumber):
                return item.partNumber == partNumber
            case let .name (name):
                guard let object = try? self.object(for: item.objectID) else { return false }
                return object.name == name
            }
        }
    }

    func object(for id: ResourceID) throws -> Object {
        guard let object = resources.resource(for: id) as? Object else {
            throw Import.Error.missingObject(id)
        }
        return object
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
        guard values.count == 4, values.allSatisfy({ $0.count == 3 }) else { return .identity }
        return Transform3D([
            [values[0][0], values[1][0], values[2][0], values[3][0]],
            [values[0][1], values[1][1], values[2][1], values[3][1]],
            [values[0][2], values[1][2], values[2][2], values[3][2]],
            [0, 0, 0, 1]
        ])
    }
}
