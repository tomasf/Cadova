import Foundation

// MARK: - 3D (Model) Support

extension Import where D == D3 {
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
        self.init {
            CachedNode(name: "import", parameters: url, parts) { _ in
                guard let format = try ModelFileFormat.detect(at: url) else {
                    throw ModelError.unrecognizedFormat
                }

                switch format {
                case .threeMF:
                    return try await ThreeMFLoader(url: url, parts: parts).load()
                case .stlBinary, .stlASCII:
                    if parts != nil {
                        throw ModelError.partsNotSupported
                    }
                    return try STLLoader(url: url).load()
                }
            }
        }
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
        self.init(model: URL(expandingFilePath: path), parts: parts)
    }

    /// Identifies a specific part of a 3MF model to import.
    public enum PartIdentifier: CacheKey {
        /// Matches an item by the name parameter of its referenced object.
        case name (String)

        /// Matches an item by its `partnumber` attribute.
        case partNumber (String)
    }

    /// Errors that can occur when importing a 3D model.
    public enum ModelError: Swift.Error {
        /// A requested part was not found in the model.
        case missingPart (Import<D3>.PartIdentifier)

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
}
