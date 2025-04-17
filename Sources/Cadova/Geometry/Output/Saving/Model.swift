import Foundation

private func saveModel(
    to name: String,
    environmentBuilder: ((inout EnvironmentValues) -> Void)?,
    providerBuilder: (EnvironmentValues) -> any OutputDataProvider,
) {
    var environment = OutputContext.current?.environmentValues ?? .defaultEnvironment
    environmentBuilder?(&environment)

    let provider = providerBuilder(environment)

    let url: URL
    if let parent = OutputContext.current?.directory {
        url = parent.appendingPathComponent(name, isDirectory: false).appendingPathExtension(provider.fileExtension)
    } else {
        url = URL(expandingFilePath: name, extension: provider.fileExtension)
    }

    do {
        try provider.writeOutput(to: url)
        logger.info("Wrote output to \(url.path)")
    } catch {
        logger.error("Failed to save model file to \(url.path): \(error)")
    }
}

public func Model(
    _ name: String,
    @GeometryBuilder3D content: @escaping () -> any Geometry3D,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) {
    saveModel(to: name, environmentBuilder: environmentBuilder) { environment in
        ThreeMFDataProvider(output: content().evaluated(in: environment))
    }
}

public func Model(
    _ name: String,
    @GeometryBuilder2D content: @escaping () -> any Geometry2D,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) {
    saveModel(to: name, environmentBuilder: environmentBuilder) { environment in
        let GeometryResult3D = content().extruded(height: 0.001).evaluated(in: environment)
        return ThreeMFDataProvider(output: GeometryResult3D)
    }
}
