import Foundation

/// A model that will be exported to a file.
///
/// Use `Model` to build geometry and write it to disk in formats like 3MF, STL, or SVG.
/// The model is created and exported in a single step using an async initializer.
///
/// `Model` is meant for a dedicated model executable, standalone or nested inside a `Project`.
/// It isn't meant to be called from an app or other code that needs to handle the error itself.
/// For that, use ``ModelFileGenerator``, which throws real errors instead of only logging them and
/// has no side effects of its own.
///
/// ```swift
/// await Model("my-part") {
///     Box(x: 10, y: 10, z: 5)
/// }
/// ```
///
/// Used standalone like this, the model is saved to `Models/my-part.3mf`, relative to the Swift
/// package root, which is derived from the caller's source file location.
///
/// Models can also be grouped within a `Project` to share environment settings and metadata
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
    /// When used standalone (not nested inside a `Project`), the model is written to
    /// `Models/<name>.3mf` relative to the Swift package root, derived from the caller's source
    /// file location, unless `name` is itself a relative or full path, in which case it's
    /// resolved against that same package-relative `Models` directory or used as-is.
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
    /// `Environment` directives apply to the entire model, including environment reads (such as
    /// `@Environment`) made directly inside the content builder. To make this possible, the
    /// builder may be evaluated more than once, so avoid relying on it running exactly once.
    /// The environment directives themselves should not depend on environment reads.
    ///
    /// - Parameters:
    ///   - name: The base filename (without extension) or a relative/full path to where the model should be saved.
    ///   - options: One or more `ModelOptions` used to customize output format, compression, metadata, etc.
    ///   - sourceFile: The path to the source file. Defaults to `#filePath`, which expands to the caller's file
    ///     path. Used to derive the package root when the model is created standalone.
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
        sourceFile: String = #filePath,
        @ModelContentBuilder content: @Sendable @escaping () -> [BuildDirective]
    ) async {
        self.name = name
        directives = content
        self.options = .init(options)

        if ModelContext.current.isCollectingModels == false {
            let sourceURL = URL(filePath: sourceFile)
            let packageRoot = sourceURL.packageRootURL ?? sourceURL.deletingLastPathComponent()
            let directory = packageRoot.appending(path: "Models", directoryHint: .isDirectory)
            try? FileManager().createDirectory(at: directory, withIntermediateDirectories: true)

            // A customizer talks to a project, so a standalone model answers it as a project of
            // its own
            if let request = CustomizerRequest.current {
                let model = self
                let project = ProjectBuild(root: directory, options: [], content: {
                    [BuildDirective(payload: .model(model))]
                })
                #if os(WASI)
                if CustomizerSession.isRequested {
                    await CustomizerSession.start(project)
                }
                #endif
                _ = await project.run(request: request, context: EvaluationContext())
                return
            }

            // Each standalone model builds as its own line runs, so it checks `--model` itself
            guard isIncluded(by: CommandLineArguments.current.modelFilter, in: []) else { return }

            // A standalone model has no `Project` above it to end the process, so its failures
            // are still only logged.
            _ = await build(URL: directory)
        }
    }

    internal func build(
        environment inheritedEnvironment: EnvironmentValues = .rootEnvironment,
        context: EvaluationContext = .init(),
        options inheritedOptions: ModelOptions? = nil,
        URL directory: URL? = nil,
        filterPath: [String] = []
    ) async -> Int {
        // A customizer's request for one model builds only that one, so its lines needn't name it
        let loggedName = CustomizerRequest.current?.model == nil ? name : nil
        return await ModelLogger.$current.withValue(ModelLogger(modelName: loggedName)) {
            if let catalog = ParameterCatalog.current {
                await recordParameters(into: catalog, environment: inheritedEnvironment, context: context,
                                       options: inheritedOptions, name: filterName(in: filterPath), groups: filterPath)
                return 0
            }
            // A customizer's preview records the parameters the model uses with the values it was
            // given, which can differ from the ones it uses with its defaults, so the page can show those
            let recorder = CustomizerRequest.current?.preview == true ? ParameterRecorder() : nil
            return await ParameterRecorder.$current.withValue(recorder) {
                await generate(environment: inheritedEnvironment, context: context, options: inheritedOptions,
                               URL: directory, recorder: recorder)
            }
        }
    }

    /// Runs the model's content and resolves the options and environment it builds with.
    private func resolveContent(
        environment inheritedEnvironment: EnvironmentValues,
        options inheritedOptions: ModelOptions?
    ) -> (directives: [BuildDirective], options: ModelOptions, environment: EnvironmentValues) {
        var directives = inheritedEnvironment.whileCurrent {
            self.directives()
        }
        let options = self.options.adding(modelName: name, defaults: inheritedOptions, directives: directives)
        let environment = inheritedEnvironment.adding(directives: directives, modelOptions: options)

        // Environment directives are collected by running the content builder, so environment
        // reads in that first run see only the inherited environment. If any directives modified
        // the environment, run the content again under the final environment and use that run's
        // geometry, so that reads and geometry agree. Environment directives and options are
        // always taken from the first run; directives must not depend on environment reads.
        if directives.containsEnvironmentDirectives {
            directives = environment.whileCurrent {
                self.directives()
            }
        }
        return (directives, options, environment)
    }

    /// Builds the model's geometry to find its parameters, without evaluating or writing it.
    private func recordParameters(
        into catalog: ParameterCatalog,
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?,
        name: String,
        groups: [String]
    ) async {
        let recorder = ParameterRecorder()
        let (metadata, parameters) = await ParameterRecorder.$current.withValue(recorder) {
            // The model's own content comes first, then its geometry, then anything only recorded
            // along the way
            let content = recorder.nested()
            let (directives, options, environment) = ParameterRecorder.$current.withValue(content) {
                resolveContent(environment: inheritedEnvironment, options: inheritedOptions)
            }
            let built = try? await directives.build(with: options, in: environment, context: context)
            return (options[Metadata.self], ParameterList.merging(content.parameters, built?.parameters ?? [], recorder.parameters))
        }
        catalog.add(.init(name: name, title: metadata.title, description: metadata.description,
                          author: metadata.author, license: metadata.license, groups: groups,
                          parameters: parameters, position: ParameterCatalog.position))
    }

    private func generate(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions?,
        URL directory: URL?,
        recorder: ParameterRecorder?
    ) async -> Int {
        let logger = ModelLogger.current
        logger.generating()

        // The model's own content records its parameters apart from its geometry's, to come first
        let contentRecorder = recorder?.nested()
        let (directives, options, environment) = ParameterRecorder.$current.withValue(contentRecorder) {
            resolveContent(environment: inheritedEnvironment, options: inheritedOptions)
        }
        var builtParameters: [ParameterDescriptor] = []

        let baseURL: URL
        if let parent = directory, !(name as NSString).isAbsolutePath {
            baseURL = parent.appendingPathComponent(name, isDirectory: false)
        } else {
            baseURL = URL(expandingFilePath: name)
        }

        let provider: OutputDataProvider
        do {
            // Building and evaluating are timed together: geometry the model reads while it's built, such as
            // bounds for alignment, is evaluated during building, so how the time splits between the two depends
            // on the model and says little on its own
            let start = ContinuousClock.now
            let warnings: [BuildWarning]
            (provider, warnings, builtParameters) = try await directives.build(with: options, in: environment, context: context)

            for warning in warnings {
                logger.buildWarning(warning)
            }

            try await provider.evaluate(context: context)
            logger.builtAndEvaluated(in: ContinuousClock.now - start)

        } catch BuildError.noGeometry {
            // Deliberately not counted as a failure. A model that builds to nothing under some
            // condition is a reasonable thing to write, and deciding otherwise is a separate
            // argument from this one.
            logger.noGeometry()
            return 0

        } catch {
            logger.evaluationFailed(error)
            return 1
        }

        let url = baseURL.appendingPathExtension(provider.fileExtension)

        // Shared by every path below — never called more than once per build.
        // Returns the number of failures, so every caller can hand it straight up.
        func write() async -> Int {
            do {
                if let recorder {
                    let info = try JSONEncoder().encode(CustomizerBuildInfo(
                        parameters: ParameterList.merging(contentRecorder?.parameters ?? [], builtParameters, recorder.parameters),
                        metadata: options[Metadata.self]
                    ))
                    try info.write(to: baseURL.appendingPathExtension(CustomizerRequest.parameterFileExtension))
                }
                // A customizer's preview reads the meshes directly. It asks for the model file itself
                // only when its visitor downloads it.
                if CustomizerRequest.current?.preview == true, let preview = try await provider.customizerPreview(context: context) {
                    let previewURL = baseURL.appendingPathExtension(CustomizerRequest.previewFileExtension)
                    try preview.write(to: previewURL)
                    logger.wrote(to: previewURL)
                    return 0
                }
                try await provider.writeOutput(to: url, context: context)
                logger.wrote(to: url)
                return 0
            } catch {
                logger.failedToSave(to: url, error)
                return 1
            }
        }

        if provider.isLikelyToReachLiveLinkListener(destination: url) {
            // The push is expected to land, making this write redundant with it — push at
            // `.high` so the listener sees it ASAP, write at `.utility` so it yields cores.
            // Gated per-path rather than "any host exists": splitting into two Tasks has real
            // overhead (~20% slower at 60 concurrent models) not worth paying for a push that
            // would just miss anyway (e.g. a host watching a different project).
            let pushTask = Task(priority: .high) {
                await provider.pushToLiveLink(destination: url, context: context)
            }
            let writeTask = Task(priority: .utility) { await write() }

            _ = await pushTask.value
            return await writeTask.value
        }

        // No listener expected — plain async-let avoids the Task-split overhead above.
        async let liveLinkPush: Bool = provider.pushToLiveLink(destination: url, context: context)
        let failures = await write()
        _ = await liveLinkPush
        return failures
    }
}

internal extension Model {
    func filterName(in path: [String]) -> String {
        (path + [name]).joined(separator: "/")
    }

    func isIncluded(by filterNames: Set<String>, in path: [String]) -> Bool {
        filterNames.isEmpty || filterNames.contains(filterName(in: path))
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
