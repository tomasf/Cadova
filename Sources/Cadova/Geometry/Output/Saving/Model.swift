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
        logger.info("Wrote output to \(url.path)")
    } catch {
        logger.error("Failed to save model file to \(url.path): \(error)")
    }
}

fileprivate extension Geometry {
    var preparedFor3DExport: any Geometry3D {
        if let geometry3D = self as? any Geometry3D {
            return geometry3D
        } else if let geometry2D = self as? any Geometry2D {
            return geometry2D.extruded(height: 0.001)
        } else {
            fatalError("Unsupported geometry type")
        }
    }
}

public func Model<D: Dimensionality>(
    _ name: String,
    @GeometryBuilder<D> content: @escaping () -> D.Geometry,
    environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
) async {
    await saveModel(to: name, environmentBuilder: environmentBuilder) { environment, context in
        let result = await content().preparedFor3DExport.build(in: environment, context: context)
        return ThreeMFDataProvider(result: result)
    }
}
