import Foundation

public func Project(
    root url: URL?,
    content: @escaping () -> Void,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) {
    var environment = EnvironmentValues.defaultEnvironment
    environmentBuilder?(&environment)

    if let url {
        try? FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    let context = OutputContext(directory: url, environmentValues: environment, evaluationContext: .init())
    context.whileCurrent {
        content()
    }
}

public func Project(
    root: String? = nil,
    content: @escaping () -> Void,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) {
    Project(root: root.map { URL(expandingFilePath: $0) }, content: content, environment: environmentBuilder)
}
