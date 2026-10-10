import Foundation
import Synchronization

/// A description of one customizer parameter, as a customizer needs to present it.
internal struct ParameterDescriptor: Sendable, Hashable {
    let label: String
    let kind: ParameterKind
    let defaultValue: String
    let minimum: String?
    let maximum: String?
    let step: String?
    let description: String?
}

/// Collects the parameters a model declares or reads while it's built.
///
/// A parameter records itself both when it's created and when it's read, so parameters stored in
/// a geometry are found even if the model never reads them with its default values, and
/// parameters declared as local variables in a `body` are found when it runs.
internal final class ParameterRecorder: Sendable {
    @TaskLocal static var current: ParameterRecorder? = nil

    private let state = Mutex<(labels: Set<String>, parameters: [ParameterDescriptor])>(([], []))

    /// Records a parameter. Parameters with the same label are one parameter, described the first
    /// way it's recorded.
    func record(_ descriptor: ParameterDescriptor) {
        state.withLock { state in
            guard state.labels.insert(descriptor.label).inserted else { return }
            state.parameters.append(descriptor)
        }
    }

    var parameters: [ParameterDescriptor] {
        state.withLock { $0.parameters }
    }
}

/// The parameters of every model in a project, collected for a customizer.
///
/// While a catalog is current, models record their parameters into it instead of being evaluated
/// and written.
internal final class ParameterCatalog: Sendable {
    @TaskLocal static var current: ParameterCatalog? = nil

    private let models = Mutex<[Model]>([])
    private let projectMetadata = Mutex<Metadata?>(nil)

    /// A model's parameters, with the title and description from its metadata for a customizer
    /// to show.
    struct Model: Sendable, Encodable {
        let name: String
        let title: String?
        let description: String?
        let parameters: [ParameterDescriptor]
    }

    /// Collects the parameters of every model in a project, for a customizer.
    ///
    /// Each model's content runs and its geometry is built, so that the parameters it creates and
    /// reads are recorded, but nothing is evaluated or written.
    static func collect(
        options: [ModelOptions],
        @ProjectContentBuilder content: @Sendable @escaping () async -> [BuildDirective]
    ) async -> ParameterCatalog {
        let catalog = ParameterCatalog()
        await $current.withValue(catalog) {
            let directives = await ModelContext(isCollectingModels: true).whileCurrent {
                await content()
            }
            let options = ModelOptions(options + directives.compactMap(\.options))
            catalog.projectMetadata.withLock { $0 = options[Metadata.self] }
            let environment = EnvironmentValues.rootEnvironment.adding(directives: directives)
            let buildables: [any ModelBuildable] = directives.compactMap(\.group) + directives.compactMap(\.model)
            let context = EvaluationContext()
            _ = await buildables.asyncMap {
                await $0.build(environment: environment, context: context, options: options, URL: nil, filterPath: [])
            }
        }
        return catalog
    }

    func add(_ model: Model) {
        models.withLock { $0.append(model) }
    }

    /// What a customizer gets: the project's own title and description, and its models.
    /// A project's metadata also applies to every model that doesn't override it, so a customizer
    /// can tell a model's own title from the project's.
    private struct Listing: Encodable {
        let title: String?
        let description: String?
        let models: [Model]
    }

    /// The catalog as JSON, for customizers to read.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = projectMetadata.withLock { $0 }
        return try encoder.encode(Listing(
            title: metadata?.title,
            description: metadata?.description,
            models: models.withLock { $0 }.sorted { $0.name < $1.name }
        ))
    }
}

extension ParameterDescriptor: Encodable {
    private enum CodingKeys: String, CodingKey {
        case label, type, options, description
        case defaultValue = "default", minimum, maximum, step
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        switch kind {
        case .integer: try container.encode("integer", forKey: .type)
        case .number: try container.encode("number", forKey: .type)
        case .angle: try container.encode("angle", forKey: .type)
        case .boolean: try container.encode("boolean", forKey: .type)
        case .text: try container.encode("text", forKey: .type)
        case .choice(let options):
            try container.encode("choice", forKey: .type)
            try container.encode(options, forKey: .options)
        }
        try container.encodeIfPresent(description, forKey: .description)
        for (value, key) in [(defaultValue, CodingKeys.defaultValue), (minimum, .minimum), (maximum, .maximum), (step, .step)] {
            guard let value else { continue }
            try encode(value, as: key, in: &container)
        }
    }

    /// Encodes a parameter string as the JSON type that matches the parameter's kind.
    private func encode(_ string: String, as key: CodingKeys, in container: inout KeyedEncodingContainer<CodingKeys>) throws {
        switch kind {
        case .integer:
            if let value = Int(string) { return try container.encode(value, forKey: key) }
        case .number, .angle:
            if let value = Double(string) { return try container.encode(value, forKey: key) }
        case .boolean:
            if let value = Bool(parameterString: string) { return try container.encode(value, forKey: key) }
        case .text, .choice:
            break
        }
        try container.encode(string, forKey: key)
    }
}
