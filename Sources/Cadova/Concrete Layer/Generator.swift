import Foundation

public struct Generator {
    private let evaluationContext = EvaluationContext()

    public init() {}

    public func build(
        named name: String? = nil,
        options: ModelOptions...,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async throws -> Product {
        let directives = content()
        let options = ModelOptions(options).adding(modelName: name, directives: directives)
        let environment = EnvironmentValues.defaultEnvironment.adding(directives: directives, modelOptions: options)

        let (dataProvider, warnings) = try await directives.build(with: options, in: environment, context: evaluationContext)
        return Product(dataProvider: dataProvider, evaluationContext: evaluationContext, buildWarnings: warnings)
    }
}

public struct Product {
    private let dataProvider: OutputDataProvider
    private let evaluationContext: EvaluationContext
    public let buildWarnings: [BuildWarning]

    public var fileExtension: String { dataProvider.fileExtension }

    internal init(dataProvider: OutputDataProvider, evaluationContext: EvaluationContext, buildWarnings: [BuildWarning]) {
        self.dataProvider = dataProvider
        self.evaluationContext = evaluationContext
        self.buildWarnings = buildWarnings
    }

    public func data() async throws -> Data {
        try await dataProvider.generateOutput(context: evaluationContext)
    }

    public func write(to fileURL: URL) async throws {
        try await dataProvider.writeOutput(to: fileURL, context: evaluationContext)
    }
}
