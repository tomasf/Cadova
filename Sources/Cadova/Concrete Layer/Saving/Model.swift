import Foundation

public struct Model: Sendable {
    let name: String
    let writer: @Sendable (EvaluationContext) async -> (URL?)

    private static let defaultContext = EvaluationContext()

    /// Creates and exports a model based on the provided geometry.
    ///
    /// Use this initializer to construct and write a 3D or 2D model to disk. The model is
    /// generated from a geometry tree you define using the result builder. Supported output
    /// formats include 3MF, STL, and SVG, and can be customized via `ModelOptions`.
    ///
    /// The model will be written to a file in the current working directory (unless a full
    /// path is specified) and revealed in Finder or Explorer if the file did not previously exist.
    ///
    /// - Parameters:
    ///   - name: The base filename (without extension) or a relative/full path to where the model should be saved.
    ///   - options: One or more `ModelOptions` used to customize output format, compression, metadata, etc.
    ///   - content: A result builder that returns the model geometry.
    ///   - environmentBuilder: An optional closure for customizing environment values. This lets you control
    ///     evaluation parameters such as segmentation detail or geometric constraints. For example, you might set:
    ///
    ///     ```swift
    ///     environment: {
    ///         $0.segmentation = .adaptive(minAngle: 4°, minSize: 0.2)
    ///         $0.maxTwistRate = 5°
    ///     }
    ///     ```
    ///
    /// ### Example
    /// ```swift
    /// await Model("example") {
    ///     Box(x: 100, y: 3, z: 20)
    ///         .deformed(using: BezierPath2D {
    ///             curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
    ///         }, with: .x)
    /// }
    /// ```
    ///
    @discardableResult
    public init<D: Dimensionality>(
        _ name: String,
        options: ModelOptions...,
        @GeometryBuilder<D> content: @Sendable @escaping () -> D.Geometry,
        environment environmentBuilder: ((inout EnvironmentValues) -> Void)? = nil
    ) async {
        self.name = name

        logger.info("Generating \"\(name)\"...")

        let localOptions: ModelOptions = [
            .init(ModelName(name: name)),
            OutputContext.current?.options ?? [],
            .init(options)
        ]

        var mutatingEnvironment = OutputContext.current?.environmentValues ?? .defaultEnvironment
        environmentBuilder?(&mutatingEnvironment)
        mutatingEnvironment.modelOptions = localOptions
        let environment = mutatingEnvironment

        let baseURL: URL
        if let parent = OutputContext.current?.directory {
            baseURL = parent.appendingPathComponent(name, isDirectory: false)
        } else {
            baseURL = URL(expandingFilePath: name)
        }

        writer = { context in
            let result: D.BuildResult
            do {
                result = try await ContinuousClock().measure {
                    try await context.buildResult(for: content(), in: environment)
                } results: { duration, _ in
                    logger.debug("Built geometry node tree in \(duration)")
                }
            } catch {
                logger.error("Cadova caught an error while evaluating model \"\(name)\":\n🛑 \(error)\n")
                return nil
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
