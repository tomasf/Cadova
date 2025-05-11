import Foundation

private func saveModel(
    to name: String,
    environmentBuilder: ((inout EnvironmentValues) -> Void)?,
    providerBuilder: (EnvironmentValues, EvaluationContext) async -> any OutputDataProvider,
) async {
    var environment = OutputContext.current?.environmentValues ?? .defaultEnvironment
    environmentBuilder?(&environment)

    let context = OutputContext.current?.evaluationContext ?? .init()
    let provider = await providerBuilder(environment, context)

    let url: URL
    if let parent = OutputContext.current?.directory {
        url = parent.appendingPathComponent(name, isDirectory: false).appendingPathExtension(provider.fileExtension)
    } else {
        url = URL(expandingFilePath: name, extension: provider.fileExtension)
    }

    do {
        try await provider.writeOutput(to: url, context: context)
        logger.info("Wrote model to \(url.path)")
    } catch {
        logger.error("Failed to save model file to \(url.path): \(error)")
    }
}

public struct Model: Sendable {
    let name: String
    let writer: @Sendable (EvaluationContext) async -> (URL?)

    private static let defaultContext = EvaluationContext()

    @discardableResult
    public init<D: Dimensionality>(
        _ name: String,
        options: ModelOptions...,
        @GeometryBuilder<D> content: @Sendable @escaping () -> D.Geometry,
        environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
    ) async {
        self.name = name

        var mutatingEnvironment = OutputContext.current?.environmentValues ?? .defaultEnvironment
        environmentBuilder?(&mutatingEnvironment)
        let environment = mutatingEnvironment

        let baseURL: URL
        if let parent = OutputContext.current?.directory {
            baseURL = parent.appendingPathComponent(name, isDirectory: false)
        } else {
            baseURL = URL(expandingFilePath: name)
        }

        let localOptions: ModelOptions = [
            .init(ModelName(name: name)),
            OutputContext.current?.options ?? [],
            .init(options)
        ]

        writer = { context in
            let result = await ContinuousClock().measure {
                await content().build(in: environment, context: context)
            } results: { duration, _ in
                logger.debug("Built geometry node tree in \(duration)")
            }

            let provider: OutputDataProvider
            if let result = result as? D2.BuildResult {
                switch localOptions[ModelOptions.FileFormat2D.self] {
                case .threeMF: provider = ThreeMFDataProvider(result: result, options: localOptions)
                case .svg: provider = SVGDataProvider(result: result, options: localOptions)
                }

            } else if let result = result as? D3.BuildResult {
                switch localOptions[ModelOptions.FileFormat3D.self] {
                case .threeMF: provider = ThreeMFDataProvider(result: result, options: localOptions)
                case .stl: provider = BinarySTLDataProvider(result: result, options: localOptions)
                }

            } else {
                preconditionFailure("Unknown result type")
            }

            let url = baseURL.appendingPathExtension(provider.fileExtension)

            let fileExisted = FileManager().fileExists(atPath: url.path())

            do {
                try await provider.writeOutput(to: url, context: context)
                logger.info("Wrote model to \(url.path)")
            } catch {
                logger.error("Failed to save model file to \(url.path): \(error)")
            }

            return fileExisted ? nil : url
        }

        if OutputContext.current == nil {
            if let url = await writer(Self.defaultContext) {
                try? Platform.revealFiles([url])
            }
        }
    }
}
