import Foundation

public func Project(
    root url: URL?,
    options: ModelOptions = [],
    @ArrayBuilder<Model> content: @escaping () async -> [Model],
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) async {
    var environment = EnvironmentValues.defaultEnvironment
    environmentBuilder?(&environment)

    if let url {
        try? FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    let outputContext = OutputContext(directory: url, environmentValues: environment, evaluationContext: .init(), options: options)
    let models = await outputContext.whileCurrent {
        await content()
    }
    guard models.isEmpty == false else { return }
    let context = EvaluationContext()

    let urls = await models.asyncCompactMap { model in
        await model.writer(context)
    }
    try? Platform.revealFiles(urls)

}

public func Project(
    root: String? = nil,
    @ArrayBuilder<Model> content: @escaping () async -> [Model],
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) async {
    await Project(root: root.map { URL(expandingFilePath: $0) }, content: content, environment: environmentBuilder)
}
