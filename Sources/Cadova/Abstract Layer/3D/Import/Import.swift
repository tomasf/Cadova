import Foundation

/// Imports geometry from an external 3D model file.
///
/// Use `Import` to bring in geometry from existing models. Supported formats are detected automatically
/// based on file contents:
/// - **3MF**: Full support including part selection by name or part number
/// - **STL**: Binary and ASCII formats (single mesh, no part selection)
///
/// ```swift
/// Import(model: "fixtures/handle.3mf")
/// Import(model: "fixtures/bracket.stl")
/// ```
///
/// For 3MF files, you can import individual parts by object name or part number:
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

    /// Creates a new imported shape from a model file URL.
    ///
    /// The file format is detected automatically from the file contents.
    ///
    /// - Parameters:
    ///   - url: The file URL to the model.
    ///   - parts: An optional list of part identifiers to import. Only supported for 3MF files.
    ///     If omitted, all parts are imported.
    ///
    public init(model url: URL, parts: [PartIdentifier]? = nil) {
        self.url = url
        self.parts = parts
    }

    /// Creates a new imported shape from a file path.
    ///
    /// The file format is detected automatically from the file contents.
    ///
    /// - Parameters:
    ///   - path: A file path to the model. Can be relative or absolute.
    ///   - parts: An optional list of part identifiers to import. Only supported for 3MF files.
    ///     If omitted, all parts are imported.
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

    /// Errors that can occur when importing a model.
    public enum Error: Swift.Error {
        /// A requested part was not found in the model.
        case missingPart (Import.PartIdentifier)

        /// Part selection was requested for a format that does not support it (e.g., STL).
        case partsNotSupported

        /// The file format could not be recognized.
        case unrecognizedFormat

        var localizedDescription: String {
            switch self {
            case .missingPart (let partIdentifier):
                "A part matching \(partIdentifier) was not found in the model."
            case .partsNotSupported:
                "Part selection is only supported for 3MF files. STL files contain a single mesh."
            case .unrecognizedFormat:
                "The file format could not be recognized. Supported formats are 3MF and STL."
            }
        }
    }

    public var body: any Geometry3D {
        CachedNode(name: "import", parameters: url, parts) { _ in
            guard let format = try ModelFileFormat.detect(at: url) else {
                throw Error.unrecognizedFormat
            }

            switch format {
            case .threeMF:
                return try await ThreeMFLoader(url: url, parts: parts).load()
            case .stlBinary, .stlASCII:
                if parts != nil {
                    throw Error.partsNotSupported
                }
                return try STLLoader(url: url).load()
            }
        }
    }
}
