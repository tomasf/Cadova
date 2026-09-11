import Foundation

/// A model that will be exported to a file.
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
/// Used standalone like this, the model is saved to `Models/my-part.3mf`, relative to the Swift
/// package root, which is derived from the caller's source file location.
///
/// Models can also be grouped within a `Project` to share environment settings and metadata
/// across multiple output files.
///
/// For fine-grained control of file output, see ``ModelFileGenerator``.
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

            await build(URL: directory)
        }
    }

    internal func build(
        environment inheritedEnvironment: EnvironmentValues = .defaultEnvironment,
        context: EvaluationContext = .init(),
        options inheritedOptions: ModelOptions? = nil,
        URL directory: URL? = nil,
        filterPath: [String] = []
    ) async {
        logger.info("Generating \"\(name)\"...")

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

        let baseURL: URL
        if let parent = directory, !(name as NSString).isAbsolutePath {
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
                logger.warning("\(warning)")
            }

        } catch BuildError.noGeometry {
            logger.error("No geometry for model \"\(name)\"")
            return

        } catch {
            logger.error("Cadova caught an error while evaluating model \"\(name)\":\n\(error)\n")
            return
        }

        let url = baseURL.appendingPathExtension(provider.fileExtension)

        // Shared by every path below — never called more than once per build.
        func write() async {
            do {
                try await provider.writeOutput(to: url, context: context)
                logger.info("Wrote model to \(url.path)")
            } catch {
                logger.error("Failed to save model file to \(url.path): \(error.descriptiveString)")
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
            await writeTask.value
            return
        }

        // No listener expected — plain async-let avoids the Task-split overhead above.
        async let liveLinkPush: Bool = provider.pushToLiveLink(destination: url, context: context)
        await write()
        _ = await liveLinkPush
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
