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
public struct Model: Sendable {
    let name: String

    public struct InMemoryFile: Sendable {
        let suggestedFileName: String
        let contents: Data
    }

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
    public init(
        _ name: String,
        options: ModelOptions...,
        automaticallyWriteToDisk: Bool = true,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async {
        self.name = name
        directives = content
        self.options = .init(options)

        if automaticallyWriteToDisk && ModelContext.current.isCollectingModels == false {
            let _ = await writeToDirectory(revealInSystemFileBrowser: true)
        }
    }

    public func writeToFile(
        _ fileUrl: URL,
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext? = nil,
        interitedOptions: ModelOptions? = nil,
        revealInSystemFileBrowser: Bool = false
    ) async throws {
        guard let file = await buildToData(environment: inheritedEnvironment, context: context ?? .init(),
                                           options: interitedOptions) else { throw CocoaError(.fileWriteUnknown) }
        do {
            try file.contents.write(to: fileUrl)
            logger.info("Wrote model to \(fileUrl.path)")
            if revealInSystemFileBrowser {
                try? Platform.revealFiles([fileUrl])
            }
        } catch {
            logger.error("Failed to save model file to \(fileUrl.path): \(error.descriptiveString)")
            throw error
        }
    }

    public func writeToDirectory(
        _ directoryUrl: URL? = nil,
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext? = nil,
        interitedOptions: ModelOptions? = nil,
        revealInSystemFileBrowser: Bool = false
    ) async -> URL? {
        let result = await buildToFile(environment: inheritedEnvironment, context: context ?? .init(),
                                       options: interitedOptions, URL: directoryUrl)
        if revealInSystemFileBrowser, let result {
            try? Platform.revealFiles([result])
        }

        return result
    }

    public func generateData(
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext? = nil,
        interitedOptions: ModelOptions? = nil
    ) async -> InMemoryFile? {
        return await buildToData(environment: inheritedEnvironment, context: context ?? .init(), options: interitedOptions)
    }

    private func buildToFile(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?,
        URL directory: URL? = nil
    ) async -> URL? {
        logger.info("Generating \"\(name)\"...")
        
        guard let file = await buildToData(environment: inheritedEnvironment,
                                           context: context, options: inheritedOptions) else { return nil }

        let url: URL
        if let parent = directory {
            url = parent.appendingPathComponent(file.suggestedFileName, isDirectory: false)
        } else {
            url = URL(expandingFilePath: file.suggestedFileName)
        }

        let fileExisted = FileManager().fileExists(atPath: url.path(percentEncoded: false))

        do {
            try file.contents.write(to: url)
            logger.info("Wrote model to \(url.path)")
        } catch {
            logger.error("Failed to save model file to \(url.path): \(error.descriptiveString)")
        }

        return fileExisted ? nil : url
    }

    private func buildToData(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?
    ) async -> InMemoryFile? {

        let directives = inheritedEnvironment.whileCurrent {
            self.directives()
        }
        let localOptions: ModelOptions = [
            .init(ModelName(name: name)),
            inheritedOptions ?? [],
            options,
            .init(directives.compactMap(\.options))
        ]

        var mutatingEnvironment = inheritedEnvironment
        for builder in directives.compactMap(\.environment) {
            builder(&mutatingEnvironment)
        }
        mutatingEnvironment.modelOptions = localOptions
        let environment = mutatingEnvironment

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

        do {
            let fileContents: Data = try await provider.generateOutput(context: context)
            return InMemoryFile(suggestedFileName: "\(name).\(provider.fileExtension)", contents: fileContents)
        } catch {
            logger.error("Cadova caught an error while generating \(provider.fileExtension) model \"\(name)\":\n🛑 \(error)\n")
            return nil
        }
    }

    private func generateResult<D: Dimensionality>(
        for geometry: D.Geometry,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> BuildResult<D> {
        let result = try await ContinuousClock().measure {
            try await environment.whileCurrent {
                try await context.buildResult(for: geometry, in: environment)
            }
        } results: { duration, _ in
            logger.debug("Built geometry node tree in \(duration)")
        }
        result.printWarnings()
        return result
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

fileprivate extension BuildResult {
    func printWarnings() {
        elements[ReferenceState.self].printWarningsAtTopLevel()
    }
}
