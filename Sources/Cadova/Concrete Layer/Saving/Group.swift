import Foundation

public func Group(
    _ name: String,
    content: @escaping () -> Void,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) {
    var environment = OutputContext.current?.environmentValues ?? .defaultEnvironment
    environmentBuilder?(&environment)

    let url: URL
    if let parent = OutputContext.current?.directory {
        url = parent.appendingPathComponent(name, isDirectory: true)
    } else {
        url = URL(expandingFilePath: name)
    }

    try? FileManager().createDirectory(at: url, withIntermediateDirectories: true)

    let evalContext = OutputContext.current?.evaluationContext ?? .init()
    let context = OutputContext(directory: url, environmentValues: environment, evaluationContext: evalContext)
    context.whileCurrent {
        content()
    }
}
