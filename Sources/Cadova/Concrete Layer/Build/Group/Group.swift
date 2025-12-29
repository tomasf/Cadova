import Foundation

/// A container for organizing models into logical groups with optional subdirectories.
///
/// Use `Group` to organize related models within a ``Project``. Groups can specify shared
/// `ModelOptions` and `EnvironmentValues` that apply to all contained models, and can
/// optionally define a subdirectory name for file organization.
///
/// Groups can be nested, allowing for hierarchical organization of models.
///
/// > Note: Unlike ``Model``, which can be used standalone, `Group` must be used within
/// > a ``Project`` or another `Group`.
///
/// In addition to `Model` and nested `Group` entries, the group's result builder also accepts:
/// - `Metadata(...)`: Attaches metadata that is combined into shared `ModelOptions`
/// - `Environment { … }` or `Environment(\.keyPath, value)`: Applies environment customizations
///   at the group scope
///
/// Precedence and merging rules:
/// - Environment and options are inherited from the parent (Project or outer Group)
/// - `Environment` directives inside the group's builder are applied on top of inherited values
/// - `Metadata` specified in the group builder is merged into shared options
/// - Nested groups and models can further override these settings
///
/// - Parameters:
///   - name: An optional subdirectory name. If provided, all models in this group will be
///     saved under this subdirectory. If `nil`, models inherit the parent's directory.
///   - options: Shared `ModelOptions` applied to all models in the group unless overridden.
///   - content: A result builder that returns an array of directives including `Model`,
///     `Group`, `Environment`, and `Metadata` entries.
///
/// ### Examples
/// ```swift
/// await Project(root: "output") {
///     await Group("parts") {
///         Environment(\.segmentation, .defaults)
///
///         await Model("bracket") { Box(10) }
///         await Model("spacer") { Cylinder(diameter: 5, height: 2) }
///     }
///
///     await Group("tools") {
///         await Model("wrench") { ... }
///     }
/// }
/// ```
///
/// Groups without names are useful for applying shared options without creating subdirectories:
/// ```swift
/// await Project(root: "output") {
///     await Group {
///         Environment(\.segmentation, .adaptive(minAngle: 5°, minSize: 0.5))
///         Metadata(author: "Acme Corp")
///
///         await Model("part1") { ... }
///         await Model("part2") { ... }
///     }
/// }
/// ```
///
public struct Group: Sendable {
    let name: String?
    private let directives: @Sendable () async -> [BuildDirective]
    private let options: ModelOptions

    /// Creates a group with an optional subdirectory name.
    ///
    /// - Parameters:
    ///   - name: An optional subdirectory name for organizing output files.
    ///   - options: Shared `ModelOptions` applied to all models in the group.
    ///   - content: A result builder that builds the group's contents.
    public init(
        _ name: String? = nil,
        options: ModelOptions...,
        @GroupContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
    ) async {
        self.name = name
        self.directives = content
        self.options = .init(options)
    }

    internal func build(
        environment inheritedEnvironment: EnvironmentValues,
        context: EvaluationContext,
        options inheritedOptions: ModelOptions,
        URL directory: URL?
    ) async -> [URL] {
        let directives = await inheritedEnvironment.whileCurrent {
            await self.directives()
        }
        let combinedOptions = ModelOptions([
            inheritedOptions,
            options,
            .init(directives.compactMap(\.options))
        ])

        var environment = inheritedEnvironment
        for builder in directives.compactMap(\.environment) {
            builder(&environment)
        }

        // Determine output directory
        let outputDirectory: URL?
        if let name {
            if let parent = directory {
                outputDirectory = parent.appendingPathComponent(name, isDirectory: true)
            } else {
                outputDirectory = URL(expandingFilePath: name)
            }
            try? FileManager().createDirectory(at: outputDirectory!, withIntermediateDirectories: true)
        } else {
            outputDirectory = directory
        }

        // Build nested content
        let models = directives.compactMap(\.model)
        let groups = directives.compactMap(\.group)

        var urls: [URL] = []

        for model in models {
            if let url = await model.build(
                environment: environment,
                context: context,
                options: combinedOptions,
                URL: outputDirectory
            ) {
                urls.append(url)
            }
        }

        for group in groups {
            let groupUrls = await group.build(
                environment: environment,
                context: context,
                options: combinedOptions,
                URL: outputDirectory
            )
            urls.append(contentsOf: groupUrls)
        }

        return urls
    }
}
