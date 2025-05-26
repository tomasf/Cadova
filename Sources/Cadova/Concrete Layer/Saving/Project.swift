import Foundation

/// Creates a group of models that share common output settings and environment values.
///
/// Use `Project` to organize and export multiple models together under a shared root directory,
/// applying the same `ModelOptions` and `EnvironmentValues` to each model unless overridden.
/// This is useful when exporting several models as a cohesive set, such as for a product or library,
/// where consistent output format, compression, or metadata is desired.
///
/// - Parameters:
///   - root: An optional base directory where all models in the project will be saved. If `nil`, files are written relative to the working directory unless individually overridden.
///   - options: Shared `ModelOptions` applied to all models in the project unless overridden.
///   - content: A result builder that asynchronously returns an array of `Model` instances to be evaluated and saved.
///   - environmentBuilder: An optional closure to customize default `EnvironmentValues` for all models in the project.
///
/// ### Example
/// ```swift
/// await Project(root: "pieces", options: .format3D(.stl)) {
///     await Model("example") {
///         Box(x: 100, y: 3, z: 20)
///             .deformed(using: BezierPath2D {
///                 curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
///             }, with: .x)
///     } environment: {
///         $0.segmentation = .adaptive(minAngle: 4°, minSize: 0.2)
///         $0.maxTwistRate = 5°
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
    options: ModelOptions = [],
    @ArrayBuilder<Model> content: @Sendable @escaping () async -> [Model],
    environment environmentBuilder: (@Sendable (inout EnvironmentValues) -> Void)? = nil
) async {
    var environment = EnvironmentValues.defaultEnvironment
    environmentBuilder?(&environment)

    if let url {
        try? FileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    let outputContext = OutputContext(directory: url, environmentValues: environment, evaluationContext: .init(), options: options)
    let models = await outputContext.whileCurrent {
        await content()
    }
    guard models.isEmpty == false else { return }
    let context = EvaluationContext()

    let urls = await models.asyncCompactMap { model in
        await model.writer(context)
    }
    try? Platform.revealFiles(urls)
}

public func Project(
    root: String? = nil,
    options: ModelOptions = [],
    @ArrayBuilder<Model> content: @Sendable @escaping () async -> [Model],
    environment environmentBuilder: (@Sendable (inout EnvironmentValues) -> Void)? = nil
) async {
    await Project(root: root.map { URL(expandingFilePath: $0) }, options: options, content: content, environment: environmentBuilder)
}
