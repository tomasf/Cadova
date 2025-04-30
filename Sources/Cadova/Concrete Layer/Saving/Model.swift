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

public struct Model: Sendable {
    let name: String
    let writer: @Sendable (EvaluationContext) async -> ()

    @discardableResult
    public init<D: Dimensionality>(
        _ name: String,
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

        writer = { context in
            let result = await ContinuousClock().measure {
                await content().preparedFor3DExport.build(in: environment, context: context)
            } results: { duration, _ in
                logger.debug("Built geometry node tree in \(duration)")
            }

            let provider = ThreeMFDataProvider(result: result)
            let url = baseURL.appendingPathExtension(provider.fileExtension)

            do {
                try await provider.writeOutput(to: url, context: context)
                logger.info("Wrote model to \(url.path)")
            } catch {
                logger.error("Failed to save model file to \(url.path): \(error)")
            }
        }

        if OutputContext.current == nil {
            let context = EvaluationContext()
            await writer(context)
        }
    }
}
