import Foundation

/// A model that can be exported to a file.
///
/// Use `Model` to build geometry and write it to disk in formats like 3MF, STL, or SVG.
/// The model is created and exported in a single step using an async initializer.
///
/// ```swift
/// await Model("my-part") {
///     Box(x: 10, y: 10, z: 5)
/// }
/// ```
///
/// Models can also be grouped within a ``Project`` to share environment settings and metadata
/// across multiple output files.
///
public struct Model: Sendable, ModelBuildable {
    let name: String

    private let directives: @Sendable () -> [BuildDirective]
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
    /// - `Environment` directives inside the model’s builder apply on top of the inherited environment and take precedence.
    /// - `Metadata` inside the model’s builder is merged into the model’s options and can augment or override
    ///   metadata inherited from the project.
    ///
    /// - Parameters:
    ///   - name: The base filename (without extension) or a relative/full path to where the model should be saved.
    ///   - options: One or more `ModelOptions` used to customize output format, compression, metadata, etc.
    ///   - content: A result builder that builds the model geometry, and may also include `Environment` and `Metadata`.
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
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async {
        self.name = name
        directives = content
        self.options = .init(options)

        if ModelContext.current.isCollectingModels == false {
            if let url = await build().first {
                try? Platform.revealFiles([url])
            }
        }
    }

    internal func build(
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext = .init(),
        options inheritedOptions: ModelOptions? = nil,
        URL directory: URL? = nil
    ) async -> [URL] {
        logger.info("Generating \"\(name)\"...")

        let directives = inheritedEnvironment.whileCurrent {
            self.directives()
        }
        let options = self.options.adding(modelName: name, defaults: inheritedOptions, directives: directives)
        let environment = inheritedEnvironment.adding(directives: directives, modelOptions: options)

        let baseURL: URL
        if let parent = directory {
            baseURL = parent.appendingPathComponent(name, isDirectory: false)
        } else {
            baseURL = URL(expandingFilePath: name)
        }

        let provider: OutputDataProvider
        do {
            let warnings: [BuildWarning]
            (provider, warnings) = try await ContinuousClock().measure {
                try await directives.build(with: options, in: environment, context: context)
            } results: { duration, _ in
                logger.debug("Built geometry node tree in \(duration)")
            }

            for warning in warnings {
                logger.warning("⚠️ \(warning.description)")
            }

        } catch BuildError.noGeometry {
            logger.error("No geometry for model \"\(name)\"")
            return []

        } catch {
            logger.error("Cadova caught an error while evaluating model \"\(name)\":\n🛑 \(error)\n")
            return []
        }

        let url = baseURL.appendingPathExtension(provider.fileExtension)
        let fileExisted = FileManager().fileExists(atPath: url.path(percentEncoded: false))

        do {
            try await provider.writeOutput(to: url, context: context)
            logger.info("Wrote model to \(url.path)")
        } catch {
            logger.error("Failed to save model file to \(url.path): \(error.descriptiveString)")
        }

        return fileExisted ? [] : [url]
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
