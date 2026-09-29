import Foundation

/// Builds a set of models and saves them to the `Models` directory of your Swift package.
///
/// `Project` is the usual entry point of a model executable. List your models in it, and they're
/// built and written to `<package-root>/Models/`, sharing whatever options, metadata and
/// environment values you set at the project level:
///
/// ```swift
/// await Project(options: .format3D(.stl)) {
///     Metadata(title: "Widget Set", author: "Acme Corp")
///     Environment {
///         $0.segmentation = .adaptive(minAngle: 10°, minSize: 1.0)
///     }
///
///     await Model("bracket") {
///         Box(x: 40, y: 10, z: 3)
///     }
///
///     await Model("spacer") {
///         Metadata(title: "Spacer")
///         Cylinder(diameter: 5, height: 2)
///     }
/// }
/// ```
///
/// The package root is found by walking up from the calling source file to the nearest directory
/// containing a `Package.swift` manifest.
///
/// In addition to `Model` entries, the project's result builder accepts:
/// - `Group(...)`: Organizes models into an optional subdirectory, with its own shared options and
///   environment. See ``Group``.
/// - `Metadata(...)`: Attaches metadata (for example title, author, license) that applies to every
///   model in the project.
/// - `Environment { … }` or `Environment(\.keyPath, value)`: Sets environment values that apply to
///   every model in the project.
///
/// Anything set at the project level is a default. A `Group` or `Model` can override it with its own
/// options, `Metadata` or `Environment` directives.
///
/// Each error is logged as it happens, and if any model fails to build or save, or an output
/// directory can't be created, `Project` then ends the process with a non-zero exit status. A model
/// Because a failure ends the process, don't call `Project` from an app or other code that needs to
/// keep running and handle the error itself. Use ``ModelFileGenerator`` there instead, which throws
/// errors rather than exiting.
///
/// To save somewhere other than `Models`, use ``Project(packageRelative:sourceFile:options:content:)``
/// or `Project(root:options:content:)`.
///
/// - Parameters:
///   - sourceFile: The path of the calling source file, used to find the package root. Leave this at
///     its default, `#filePath`.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: The models, groups, metadata and environment values that make up the project.
///
public func Project(
    sourceFile: String = #filePath,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    await Project(
        packageRelative: "Models",
        sourceFile: sourceFile,
        options: .init(options),
        content: content
    )
}

/// Builds a set of models and saves them to a directory inside your Swift package.
///
/// This works like ``Project(sourceFile:options:content:)``, including ending the process with a
/// non-zero exit status if the build fails, but saves to `<package-root>/<root>` instead of
/// `<package-root>/Models`.
///
/// ```swift
/// await Project(packageRelative: "Output/Parts") {
///     await Model("example") {
///         Box(10)
///     }
/// }
/// ```
///
/// - Parameters:
///   - root: The directory, relative to the package root, where models are saved.
///   - sourceFile: The path of the calling source file, used to find the package root. Leave this at
///     its default, `#filePath`.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: The models, groups, metadata and environment values that make up the project.
///
public func Project(
    packageRelative root: String,
    sourceFile: String = #filePath,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    let sourceURL = URL(filePath: sourceFile)
    let packageRoot = sourceURL.packageRootURL ?? sourceURL.deletingLastPathComponent()
    let outputURL = packageRoot.appending(path: root, directoryHint: .isDirectory)

    await Project(
        root: outputURL,
        options: .init(options),
        content: content
    )
}

/// Builds a set of models and saves them to a directory given as a path.
///
/// This works like ``Project(sourceFile:options:content:)``, including ending the process with a
/// non-zero exit status if the build fails, but saves to a directory you name directly instead of
/// one inside your Swift package.
///
/// ```swift
/// await Project(root: "~/Desktop/Parts") {
///     await Model("example") {
///         Box(10)
///     }
/// }
/// ```
///
/// - Parameters:
///   - root: The directory where models are saved. It may start with `~` for the home directory, and
///     a relative path is resolved against the working directory. If `nil`, models are saved to the
///     working directory. A model whose name is an absolute path is saved there instead.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: The models, groups, metadata and environment values that make up the project.
///
public func Project(
    root: String?,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    await Project(
        root: root.map { URL(expandingFilePath: $0) },
        options: .init(options),
        content: content
    )
}

/// Builds a set of models and saves them to a directory given as a URL.
///
/// This works like ``Project(sourceFile:options:content:)``, including ending the process with a
/// non-zero exit status if the build fails, but saves to the directory you pass instead of one
/// inside your Swift package.
///
/// - Parameters:
///   - url: The directory where models are saved. If `nil`, models are saved to the working
///     directory. A model whose name is an absolute path is saved there instead.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: The models, groups, metadata and environment values that make up the project.
///
public func Project(
    root url: URL?,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    func endBuild(failureCount: Int) {
        guard failureCount > 0 else { return }
        logger.error("Build failed with \(failureCount) error\(failureCount == 1 ? "" : "s").")
        exit(EXIT_FAILURE)
    }

    // Collect directives
    let directives = await ModelContext(isCollectingModels: true).whileCurrent {
        await content()
    }

    var failures = 0

    if let url {
        // Reported once for the directory, rather than once per model that then cannot be saved
        // into it. The models are still attempted, in case they name absolute paths of their own.
        do {
            try FileManager().createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create output directory \(url.path): \(error.descriptiveString)")
            failures += 1
        }
    }

    var combinedOptions = ModelOptions(options + directives.compactMap(\.options))
    let environment = EnvironmentValues.defaultEnvironment.adding(directives: directives)

    let models = directives.compactMap(\.model)

    let cliArgs = CommandLineArguments.current
    if !cliArgs.modelFilter.isEmpty {
        combinedOptions = [combinedOptions, ModelOptions(ModelFilter(names: cliArgs.modelFilter))]
        logger.info("Model filter: \(cliArgs.modelFilter.sorted().joined(separator: ", "))")
    }

    // Build models and groups
    let groups = directives.compactMap(\.group)
    guard models.isEmpty == false || groups.isEmpty == false else {
        endBuild(failureCount: failures)
        return
    }
    let context = EvaluationContext()

    let constantEnvironment = environment

    let filterNames = combinedOptions[ModelFilter.self].names
    let filteredModels = models.filter { $0.isIncluded(by: filterNames, in: []) }
    let buildables: [any ModelBuildable] = groups + filteredModels
    let finalOptions = combinedOptions
    failures += await buildables.asyncMap {
        await $0.build(environment: constantEnvironment, context: context, options: finalOptions, URL: url, filterPath: [])
    }.reduce(0, +)

    endBuild(failureCount: failures)
}
