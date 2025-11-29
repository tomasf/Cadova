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
/// - The `environment` closure parameter to `Project` establishes a base environment for the project.
/// - Any `Environment` directives inside the project's content builder are applied on top of that base,
///   affecting all models unless overridden at the model level.
/// - Per-model environment (either via the model’s own `environment:` closure or `Environment` directives
///   inside the model’s result builder) takes precedence over project-level settings.
/// - `Metadata` specified in the project builder is merged into shared `ModelOptions` and applied to all models,
///   and can be further augmented or overridden by per-model options/metadata.
///
/// - Parameters:
///   - url: An optional base directory where all models in the project will be saved. If `nil`, files are written
///     relative to the working directory unless individually overridden.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: A result builder that asynchronously returns an array of directives. It can include `Model` instances
///     to be evaluated and saved, as well as `Environment` and `Metadata` directives that set project-wide defaults.
///   - environmentBuilder: An optional closure to customize default `EnvironmentValues` for all models in the project.
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
/// } environment: {
///     // Base environment for the project (lowest precedence)
///     $0.tolerance = 0.2
/// }
/// ```
///
public func Project(
    root url: URL?,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective],
    environment environmentBuilder: (@Sendable (inout EnvironmentValues) -> Void)? = nil
) async {
    var environment = EnvironmentValues.defaultEnvironment
    environmentBuilder?(&environment)

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

    // Build models
    guard models.isEmpty == false else { return }
    let context = EvaluationContext()

    let constantEnvironment = environment
    let urls = await models.asyncCompactMap { model in
        await model.build(environment: constantEnvironment, context: context, options: combinedOptions, URL: url)
    }
    try? Platform.revealFiles(urls)
}

public func Project(
    root: String? = nil,
    options: ModelOptions...,
    @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective],
    environment environmentBuilder: (@Sendable (inout EnvironmentValues) -> Void)? = nil
) async {
    await Project(
        root: root.map { URL(expandingFilePath: $0) },
        options: .init(options),
        content: content,
        environment: environmentBuilder
    )
}
