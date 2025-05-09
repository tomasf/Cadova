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

    /// Errors that can occur during 3MF import.
    public enum Error: Swift.Error {
        /// A requested part was not found in the model.
        case missingPart (Import.PartIdentifier)

        /// A referenced object could not be resolved.
        case missingObject
    }

    public var body: any Geometry3D {
        CachedBoxedGeometry(operationName: "import", parameters: url, parts) {
            do {
                let model = try PackageReader(url: url).model()
                return try model.geometry(for: parts)
            } catch {
                logger.error("Failed to read 3MF model \(url.path): \(error)")
                return Empty()
            }
        }
    }
}

internal extension ThreeMF.Model {
    func geometry(for parts: [Import.PartIdentifier]?) throws -> any Geometry3D {
        if let partsIDs = parts {
            return try Union(partsIDs.map {
                guard let item = firstItem(matching: $0) else {
                    throw Import.Error.missingPart($0)
                }
                return try geometry(for: item)
            })
        } else {
            return try Union(buildItems.map { try geometry(for: $0) })
        }
    }

    func geometry(for item: ThreeMF.Item) throws -> any Geometry3D {
        let object = try self.object(for: item.objectID)
        let geometry = try self.geometry(for: object)

        return if let transform = item.transform {
            geometry.transformed(transform.affineTransform3D)
        } else {
            geometry
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
            throw Import.Error.missingObject
        }
        return object
    }

    func geometry(for object: ThreeMF.Object) throws -> any Geometry3D {
        switch object.content {
        case .mesh (let mesh):
            return Mesh(.init(mesh))

        case .components (let components):
            return try components.mapUnion { component in
                let subobject = try self.object(for: component.objectID)
                let subgeometry = try self.geometry(for: subobject)
                if let transform = component.transform {
                    subgeometry.transformed(transform.affineTransform3D)
                } else {
                    subgeometry
                }
            }
        }
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
    var affineTransform3D: Transform3D {
        guard values.count == 12 else { return .identity }
        return Transform3D([
            values[0] + [0], values[1] + [0], values[2] + [0], values[3] + [1]
        ])
    }
}
