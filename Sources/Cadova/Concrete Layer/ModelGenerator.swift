import Foundation

public struct ModelFileGenerator {
    private let evaluationContext = EvaluationContext()

    public init() {}

    public func build(
        named name: String? = nil,
        options: ModelOptions...,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async throws -> ModelFile {
        let directives = content()
        let options = ModelOptions(options).adding(modelName: name, directives: directives)
        let environment = EnvironmentValues.defaultEnvironment.adding(directives: directives, modelOptions: options)

        let (dataProvider, warnings) = try await directives.build(with: options, in: environment, context: evaluationContext)
        return ModelFile(dataProvider: dataProvider, evaluationContext: evaluationContext, modelName: name,
                         buildWarnings: warnings)
    }
}

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

    public let buildWarnings: [BuildWarning]

    public var fileExtension: String { dataProvider.fileExtension }

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

    public func data() async throws -> Data {
        try await dataProvider.generateOutput(context: evaluationContext)
    }

    public func write(to fileURL: URL) async throws {
        try await dataProvider.writeOutput(to: fileURL, context: evaluationContext)
    }
}
