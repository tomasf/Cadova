import Foundation

/// Creates a group of models that share common output settings and environment values.
///
/// Use `Project` to organize and export multiple models together under a shared root directory,
/// applying the same `ModelOptions` and `EnvironmentValues` to each model unless overridden.
/// This is useful when exporting several models as a cohesive set, such as for a product or library,
/// where consistent output format, compression, or metadata is desired.
///
/// In addition to `Model` entries, the project's result builder also accepts:
/// - `Metadata(...)`: Attaches metadata that is combined into the project's shared `ModelOptions`
///   (for example title, author, license). This metadata is merged and applied to all models unless
///   further overridden.
/// - `Environment { … }` or `Environment(\.keyPath, value)`: Applies environment customizations at
///   the project scope. These values become defaults for all models in the project unless a model
///   provides its own overrides.
///
/// Precedence and merging rules:
/// - Environment defaults start from `EnvironmentValues.defaultEnvironment`.
/// - Any `Environment` directives inside the project's content builder are applied on top of that base,
///   affecting all models unless overridden at the model level.
/// - Per-model environment specified via `Environment` directives inside the model’s result builder
///   takes precedence over project-level settings.
/// - `Metadata` specified in the project builder is merged into shared `ModelOptions` and applied to all models,
///   and can be further augmented or overridden by per-model options/metadata.
///
/// - Parameters:
///   - url: An optional base directory where all models in the project will be saved. If `nil`, files are written
///     relative to the working directory unless individually overridden.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: A result builder that asynchronously returns an array of directives. It can include `Model` instances
///     to be evaluated and saved, as well as `Environment` and `Metadata` directives that set project-wide defaults.
///
/// ### Example
/// ```swift
/// await Project(root: "pieces", options: .format3D(.stl)) {
///     // Project-wide metadata and environment defaults
///     Metadata(
///         title: "Widget Set",
///         author: "Acme Corp"
///     )
///     Environment(\.horizontalTextAlignment, .right)
///     Environment {
///         $0.segmentation = .adaptive(minAngle: 10°, minSize: 1.0)
///         $0.maxTwistRate = 5°
///     }
///
///     await Model("example") {
///         // Model-local overrides
///         Environment { $0.segmentation = .defaults }
///         Metadata(title: "Deformed Box")
///
///         Box(x: 100, y: 3, z: 20)
///             .deformed(by: BezierPath2D {
///                 curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
///             })
///     }
///
///     await Model("box") {
///         Box(10)
///     }
/// }
/// ```
///
public func Project(
    root url: URL?,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    var environment = EnvironmentValues.defaultEnvironment

    if let url {
        try? FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    // Collect directives
    let directives = await ModelContext(isCollectingModels: true).whileCurrent {
        await content()
    }
    let models = directives.compactMap(\.model)
    let combinedOptions = ModelOptions(options + directives.compactMap(\.options))
    for builder in directives.compactMap(\.environment) {
        builder(&environment)
    }

    // Build models and groups
    let groups = directives.compactMap(\.group)
    guard models.isEmpty == false || groups.isEmpty == false else { return }
    let context = EvaluationContext()

    let constantEnvironment = environment
    var urls: [URL] = []

    for model in models {
        if let modelUrl = await model.writeToDirectory(url, environment: constantEnvironment, context: context,
                                                       inheritedOptions: combinedOptions, revealInSystemFileBrowser: false) {
            urls.append(modelUrl)
        }
    }

    for group in groups {
        let groupUrls = await group.build(environment: constantEnvironment, context: context, options: combinedOptions, URL: url)
        urls.append(contentsOf: groupUrls)
    }

    try? Platform.revealFiles(urls)
}

public func Project(
    root: String? = nil,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
) async {
    await Project(
        root: root.map { URL(expandingFilePath: $0) },
        options: .init(options),
        content: content
    )
}

/// Creates a project with the output directory relative to the Swift package root.
///
/// This convenience initializer derives the package root from the source file path by finding
/// the `Sources` directory and using its parent. The output directory is then created at
/// `<package-root>/<packageRelative>`.
///
/// - Parameters:
///   - packageRelative: The path relative to the package root where models will be saved.
///   - sourceFile: The path to the source file. Defaults to `#filePath`, which expands to the caller's file path.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: A result builder that asynchronously returns an array of directives.
///
/// ### Example
/// ```swift
/// await Project(packageRelative: "Models") {
///     await Model("example") {
///         Box(10)
///     }
/// }
/// ```
///
/// This will save models to `<package-root>/Models/`.
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

private extension URL {
    /// Finds the package root by locating the last `Sources` component in the path
    /// and returning its parent directory.
    var packageRootURL: URL? {
        var url = self
        while url.pathComponents.count > 1 {
            if url.lastPathComponent == "Sources" {
                return url.deletingLastPathComponent()
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
