import Foundation

public struct Model: Sendable {
    let name: String

    private let directives: [BuildDirective]
    private let environmentBuilder: (@Sendable (inout EnvironmentValues) -> ())?
    private let options: ModelOptions

    /// Creates and exports a model based on the provided geometry.
    ///
    /// Use this initializer to construct and write a 3D or 2D model to disk. The model is
    /// generated from a geometry tree you define using the result builder. Supported output
    /// formats include 3MF, STL, and SVG, and can be customized via `ModelOptions`.
    ///
    /// The model will be written to a file in the current working directory (unless a full
    /// path is specified) and revealed in Finder or Explorer if the file did not previously exist.
    ///
    /// In addition to geometry, the model’s result builder also accepts:
    /// - `Metadata(...)`: Attaches metadata (e.g. title, author, license) that is merged into the model’s options.
    /// - `Environment { … }` or `Environment(\.keyPath, value)`: Applies environment customizations for this model.
    ///
    /// Precedence and merging rules:
    /// - Any environment inherited from a parent `Project` (if present) forms the base.
    /// - The `environment` closure parameter on `Model` is applied on top of the inherited environment.
    /// - `Environment` directives inside the model’s builder then apply last and take precedence.
    /// - `Metadata` inside the model’s builder is merged into the model’s options and can augment or override
    ///   metadata inherited from the project.
    ///
    /// - Parameters:
    ///   - name: The base filename (without extension) or a relative/full path to where the model should be saved.
    ///   - options: One or more `ModelOptions` used to customize output format, compression, metadata, etc.
    ///   - content: A result builder that builds the model geometry, and may also include `Environment` and `Metadata`.
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
    /// ### Examples
    /// ```swift
    /// await Model("simple") {
    ///     Box(x: 10, y: 10, z: 5)
    /// }
    /// ```
    ///
    /// ```swift
    /// await Model("complex") {
    ///     // Model-local metadata and environment
    ///     Metadata(title: "Complex", description: "A more complex example of using Model")
    ///
    ///     Environment {
    ///         $0.segmentation = .adaptive(minAngle: 10°, minSize: 0.5)
    ///     }
    ///
    ///     Box(x: 100, y: 3, z: 20)
    ///         .deformed(by: BezierPath2D {
    ///             curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
    ///         })
    /// }
    /// ```
    ///
    @discardableResult
    public init(
        _ name: String,
        options: ModelOptions...,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective],
        environment environmentBuilder: (@Sendable (inout EnvironmentValues) -> Void)? = nil
    ) async {
        self.name = name
        self.environmentBuilder = environmentBuilder
        directives = content()
        self.options = .init(options)

        if ModelContext.current.isCollectingModels == false {
            if let url = await build() {
                try? Platform.revealFiles([url])
            }
        }
    }

    internal func build(
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext = .init(),
        options inheritedOptions: ModelOptions? = nil,
        URL directory: URL? = nil
    ) async -> URL? {
        logger.info("Generating \"\(name)\"...")

        let localOptions: ModelOptions = [
            .init(ModelName(name: name)),
            inheritedOptions ?? [],
            options,
            .init(directives.compactMap(\.options))
        ]

        var mutatingEnvironment = inheritedEnvironment
        environmentBuilder?(&mutatingEnvironment)
        for builder in directives.compactMap(\.environment) {
            builder(&mutatingEnvironment)
        }
        mutatingEnvironment.modelOptions = localOptions
        let environment = mutatingEnvironment

        let baseURL: URL
        if let parent = directory {
            baseURL = parent.appendingPathComponent(name, isDirectory: false)
        } else {
            baseURL = URL(expandingFilePath: name)
        }

        let geometries3D = directives.compactMap(\.geometry3D)
        let geometries2D = directives.compactMap(\.geometry2D)
        let provider: OutputDataProvider

        do {
            if geometries3D.count > 0 {
                let promotedFrom2D = geometries2D.map { $0.promotedTo3D() }
                let result = try await generateResult(for: Union(geometries3D + promotedFrom2D), in: environment, context: context)

                switch localOptions[ModelOptions.FileFormat3D.self] {
                case .threeMF: provider = ThreeMFDataProvider(result: result, options: localOptions)
                case .stl: provider = BinarySTLDataProvider(result: result, options: localOptions)
                }

            } else if geometries2D.count > 0 {
                let result = try await generateResult(for: Union(geometries2D), in: environment, context: context)

                switch localOptions[ModelOptions.FileFormat2D.self] {
                case .threeMF: provider = ThreeMFDataProvider(result: result.promotedTo3D(), options: localOptions)
                case .svg: provider = SVGDataProvider(result: result, options: localOptions)
                }
            } else {
                logger.warning("No geometry for model \"\(name)\"")
                return nil
            }
        } catch {
            logger.error("Cadova caught an error while evaluating model \"\(name)\":\n🛑 \(error)\n")
            return nil
        }

        let url = baseURL.appendingPathExtension(provider.fileExtension)
        let fileExisted = FileManager().fileExists(atPath: url.path())

        do {
            try await provider.writeOutput(to: url, context: context)
            logger.info("Wrote model to \(url.path)")
        } catch {
            logger.error("Failed to save model file to \(url.path): \(error.descriptiveString)")
        }

        return fileExisted ? nil : url
    }

    private func generateResult<D: Dimensionality>(
        for geometry: D.Geometry,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> BuildResult<D> {
        try await ContinuousClock().measure {
            try await environment.whileCurrent {
                try await context.buildResult(for: geometry, in: environment)
            }
        } results: { duration, _ in
            logger.debug("Built geometry node tree in \(duration)")
        }
    }
}

extension Error {
    var descriptiveString: String {
        if let localized = self as? any LocalizedError, let desc = localized.errorDescription {
            String(describing: self) + ": " + desc
        } else {
            String(describing: self)
        }
    }
}

fileprivate extension Geometry2D {
    func promotedTo3D() -> any Geometry3D {
        extruded(height: 0.001)
    }
}
