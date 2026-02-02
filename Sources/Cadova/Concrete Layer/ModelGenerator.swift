import Foundation

/// A model that will be rendered into a standard file format.
///
/// Use `ModelFileGenerator` to build geometry into standard file formats like 3MF, STL, or SVG.
/// The model is rendered into a `ModelFile`, from which data can be accessed in memory or written
/// to disk.
///
/// ```swift
/// let modelFile = try await ModelFileGenerator.build(named: "my-part") {
///     Box(x: 10, y: 10, z: 5)
/// }
///
/// let fileName = modelFile.suggestedFileName
/// let fileData = try await modelFile.data()
/// ```
///
/// For command-line apps, see ``Model`` for a pre-built convenient workflow for outputting to
/// the current working directory.
public struct ModelFileGenerator {
    
    /// Render a one-shot model to a model file.
    ///
    /// For more details, see the documentation for the ``ModelFileGenerator.build()``
    /// instance method.
    ///
    /// - Note: If you intend to render geometries more than once, create an instance of
    ///         ``ModelFileGenerator`` and re-use ``build()`` on that instance instead.
    ///         Instances maintain a cache for improved performance over multiple builds.
    public static func build(
        named name: String? = nil,
        options: ModelOptions...,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async throws -> ModelFile {
        return try await ModelFileGenerator().build(named: name, options: options, content: content)
    }

    private let evaluationContext = EvaluationContext()
    
    /// Creates a ``ModelFileGenerator`` instance. Instances maintain a cache, allowing improved
    /// performance when performing multiple, subsequent builds.
    public init() {}

    /// Renders a model to a standard file format based on the provided geometry.
    ///
    /// Use this function to construct a 3D or 2D model to a file which can then be used in memory
    /// or written to disk. The model is generated from a geometry tree you define using the result
    /// builder. Supported output formats include 3MF, STL, and SVG, and can be customized via `ModelOptions`.
    ///
    /// The model will be rendered into a ``ModelFile`` object which can be used to access the file's
    /// contents, get a suggested file name, and write the file to disk.
    ///
    /// In addition to geometry, the model’s result builder also accepts:
    /// - `Metadata(...)`: Attaches metadata (e.g. title, author, license) that is merged into the model’s options.
    /// - `Environment { … }` or `Environment(\.keyPath, value)`: Applies environment customizations for this model.
    ///
    /// Precedence and merging rules:
    /// - `Environment` directives inside the model’s builder form the base.
    /// - `Metadata` inside the model’s builder is merged into the model’s options.
    ///
    /// - Parameters:
    ///   - name: The base name of the model, which will be used to generate a suggested file name.
    ///   - options: One or more `ModelOptions` used to customize output format, compression, metadata, etc.
    ///   - content: A result builder that builds the model geometry, and may also include `Environment` and `Metadata`.
    ///
    /// - Returns: Returns the constructed file in the form of a ``ModelFile`` object.
    ///
    /// ### Examples
    ///
    /// ```swift
    /// let fileData: Data = try await ModelFileGenerator.build(named: "simple") {
    ///     Box(x: 10, y: 10, z: 5)
    /// }.data()
    /// ```
    ///
    /// ```swift
    /// let modelGenerator = ModelFileGenerator()
    /// let file: ModelFile = try await modelGenerator.build(named: "complex", options: .format3D(.threeMF)) {
    ///     // Model-local metadata and environment
    ///     Metadata(title: "Complex", description: "A more complex example of using ModelFileGenerator")
    ///
    ///     Environment {
    ///         $0.segmentation = .adaptive(minAngle: 10°, minSize: 0.5)
    ///     }
    ///
    ///     Box(x: 100, y: 3, z: 20)
    ///         .deformed(by: BezierPath2D {
    ///             curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
    ///         })
    /// }
    ///
    /// let url = try await presentSaveDialog(defaultName: file.suggestedFileName)
    /// try await file.write(to: url)
    /// ```
    public func build(
        named name: String? = nil,
        options: ModelOptions...,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async throws -> ModelFile {
        return try await build(named: name, options: options, content: content)
    }

    internal func build(
        named name: String? = nil,
        options: [ModelOptions],
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async throws -> ModelFile {
        // This is here because in Swift, a varadic parameter can't be passed along as a varadic
        // parameter (i.e., the static method can't call the instance method without this).
        let directives = content()
        let options = ModelOptions(options).adding(modelName: name, directives: directives)
        let environment = EnvironmentValues.defaultEnvironment.adding(directives: directives, modelOptions: options)

        let (dataProvider, warnings) = try await directives.build(with: options, in: environment, context: evaluationContext)
        return ModelFile(dataProvider: dataProvider, evaluationContext: evaluationContext, modelName: name,
                         buildWarnings: warnings)
    }
}

/// A representation of a model in the form of a standard file format (3MF, STL, SVG, etc).
public struct ModelFile {
    private let dataProvider: OutputDataProvider
    private let evaluationContext: EvaluationContext
    private let modelName: String?

    internal init(dataProvider: OutputDataProvider, evaluationContext: EvaluationContext, modelName: String?,
                  buildWarnings: [BuildWarning]) {
        self.dataProvider = dataProvider
        self.evaluationContext = evaluationContext
        self.modelName = modelName
        self.buildWarnings = buildWarnings
    }
    
    /// Any warnings generated during the build process.
    public let buildWarnings: [BuildWarning]
    
    /// The file's file extension, such as `3mf`, `stl`, etc.
    public var fileExtension: String { dataProvider.fileExtension }
    
    /// The file's suggested name, including extension, based on the model name given when built.
    /// Illegal file name characters will be removed based on the current platform.
    public var suggestedFileName: String {
        let invalidCharacters: String
        #if os(Windows)
        // https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
        invalidCharacters = "<>:\"/\\|?*"
        #elseif os(Linux)
        invalidCharacters = "/"
        #else
        // Assume an Apple platform.
        // ':' is technically allowed, but for legacy reasons is displayed as '/' in the Finder.
        invalidCharacters = ":/"
        #endif

        var disallowedCharacterSet: CharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(32))
        disallowedCharacterSet.insert(charactersIn: invalidCharacters)

        var sanitizedFileName: String = (modelName ?? "Model")
        sanitizedFileName.unicodeScalars.removeAll(where: { disallowedCharacterSet.contains($0) })
        if sanitizedFileName.isEmpty { sanitizedFileName = "Model" }
        return "\(sanitizedFileName).\(fileExtension)"
    }
    
    /// Generates the file's contents as in-memory data.
    public func data() async throws -> Data {
        try await dataProvider.generateOutput(context: evaluationContext)
    }
    
    /// Writes the file's contents to the given location on disk.
    public func write(to fileURL: URL) async throws {
        try await dataProvider.writeOutput(to: fileURL, context: evaluationContext)
    }
}
