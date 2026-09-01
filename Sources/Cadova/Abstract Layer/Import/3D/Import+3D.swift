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
            CachedNode(name: "Cadova.Import", parameters: url, parts) { context in
                guard let format = try ModelFileFormat.detect(at: url) else {
                    throw ModelError.unrecognizedFormat
                }

                switch format {
                case .threeMF:
                    return try await ThreeMFLoader(url: url, parts: parts).load(context: context)
                case .stlBinary, .stlASCII:
                    if parts != nil {
                        throw ModelError.partsNotSupported
                    }
                    return try STLLoader(url: url).load()
                }
            }
        }
    }

    /// Creates a new imported shape from a model file URL, transforming each part of the model.
    ///
    /// The closure is called once for every part in the file, receiving that part's geometry along
    /// with a ``ModelPart`` describing it. Whatever the closure returns takes the part's place in
    /// the result, which makes it the way to filter, route and modify parts on import:
    ///
    /// ```swift
    /// Import(model: url) { geometry, part in
    ///     if part.name == "Handle" {
    ///         geometry.inPart(handle)   // route this part into a Part
    ///     } else if part.name != "Support" {
    ///         geometry                  // merge this part into the main output
    ///     }
    /// }
    /// ```
    ///
    /// Producing nothing for a part, as the missing branch does for "Support" above, leaves that
    /// part out of the import entirely.
    ///
    /// Only supported for 3MF files; STL files always contain a single mesh and can't be imported
    /// through this initializer.
    ///
    /// - Parameters:
    ///   - url: The file URL to the model.
    ///   - parts: A closure receiving each part's geometry and its ``ModelPart`` description, and
    ///     returning the geometry to use in its place, or nothing to leave the part out. All
    ///     returned geometry is combined with a union.
    ///
    public init(
        model url: URL,
        @GeometryBuilder3D parts: @Sendable @escaping (_ geometry: any Geometry3D, _ part: ModelPart) throws -> any Geometry3D
    ) {
        self.init {
            PartedImport(source: .url(url), parts: parts)
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

    /// Creates a new imported shape from a file path, transforming each part of the model.
    ///
    /// - Parameters:
    ///   - path: A file path to the model. Can be relative or absolute.
    ///   - parts: A closure receiving each part's geometry and its ``ModelPart`` description, and
    ///     returning the geometry to use in its place. See the URL variant of this initializer
    ///     for details.
    ///
    public init(
        model path: String,
        @GeometryBuilder3D parts: @Sendable @escaping (_ geometry: any Geometry3D, _ part: ModelPart) throws -> any Geometry3D
    ) {
        self.init(model: URL(expandingFilePath: path), parts: parts)
    }

    /// Creates a new imported shape from model file data.
    ///
    /// The file format is detected automatically from the data.
    ///
    /// - Parameters:
    ///   - data: The data of the model.
    ///   - parts: An optional list of part identifiers to import. Only supported for 3MF.
    ///     If omitted, all parts are imported.
    ///
    public init<T: DataProtocol>(model data: T, parts: [PartIdentifier]? = nil) {
        let resolvedData = Data(data)
        self.init {
            CachedNode(name: "Cadova.Import", parameters: resolvedData, parts) { context in
                guard let format = ModelFileFormat.detect(from: resolvedData) else {
                    throw ModelError.unrecognizedFormat
                }

                switch format {
                case .threeMF:
                    return try await ThreeMFLoader(data: resolvedData, parts: parts).load(context: context)
                case .stlBinary, .stlASCII:
                    if parts != nil {
                        throw ModelError.partsNotSupported
                    }
                    return try STLLoader(data: resolvedData).load()
                }
            }
        }
    }

    /// Creates a new imported shape from model file data, transforming each part of the model.
    ///
    /// - Parameters:
    ///   - data: The data of the model.
    ///   - parts: A closure receiving each part's geometry and its ``ModelPart`` description, and
    ///     returning the geometry to use in its place. See the URL variant of this initializer
    ///     for details.
    ///
    public init<T: DataProtocol>(
        model data: T,
        @GeometryBuilder3D parts: @Sendable @escaping (_ geometry: any Geometry3D, _ part: ModelPart) throws -> any Geometry3D
    ) {
        let resolvedData = Data(data)
        self.init {
            PartedImport(source: .data(resolvedData), parts: parts)
        }
    }

    /// Identifies a specific part of a 3MF model to import.
    public enum PartIdentifier: CacheKey {
        /// Matches an item by the name parameter of its referenced object.
        case name (String)

        /// Matches an item by its `partnumber` attribute.
        case partNumber (String)
    }

    /// Describes one part of an imported 3MF model.
    ///
    /// A value of this type is handed to the part-mapping `Import` initializers' closure once for
    /// each part in the file, describing the part whose geometry accompanies it.
    public struct ModelPart: Sendable, Hashable {
        /// The position of this part among the file's build items, starting at zero.
        public let index: Int

        /// The name of the object this part refers to, or `nil` if it has none.
        public let name: String?

        /// The `partnumber` attribute of this part, or `nil` if it has none.
        public let partNumber: String?

        /// A name suitable for a ``Part``, derived from the part's ``name``, its ``partNumber`` or,
        /// failing both, its position in the file.
        public let defaultName: String

        internal init(index: Int, name: String?, partNumber: String?) {
            self.index = index
            self.name = name
            self.partNumber = partNumber
            self.defaultName = name ?? partNumber ?? "Part \(index + 1)"
        }
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
                "A part matching \(partIdentifier.selectorDescription) was not found in the model."
            case .partsNotSupported:
                "Part selection is only supported for 3MF files. STL files contain a single mesh."
            case .unrecognizedFormat:
                "The file format could not be recognized. Supported formats are 3MF and STL."
            }
        }
    }
}

private extension Import<D3>.PartIdentifier {
    var selectorDescription: String {
        switch self {
        case .name (let name): "name \"\(name)\""
        case .partNumber (let partNumber): "part number \"\(partNumber)\""
        }
    }
}
