import Foundation
import Synchronization

/// A description of one customizer parameter, as a customizer needs to present it.
internal struct ParameterDescriptor: Sendable, Hashable {
    let key: String
    let label: String
    let kind: ParameterKind
    let defaultValue: String
    let minimum: String?
    let maximum: String?
    let step: String?
    let unit: String?
    let description: String?
}

extension ParameterDescriptor {
    /// A parameter's key: an opaque digest of where it's declared and its label. It only has to agree
    /// between a customizer and the model built along with it, so it needn't survive edits to the
    /// model, and doesn't reveal its source.
    static func key(label: String, fileID: String, line: Int, column: Int) -> String {
        var hasher = StableHasher()
        for text in [fileID, label] {
            let bytes = Array(text.utf8)
            hasher.combine(bytes.count)
            hasher.combine(bytes: bytes)
        }
        hasher.combine(line)
        hasher.combine(column)
        let digest = hasher.finalize()
        return [digest.high, digest.low].map { word in
            let hex = String(word, radix: 16)
            return String(repeating: "0", count: 16 - hex.count) + hex
        }.joined()
    }
}

/// Collects the parameters a model declares or reads while it's built.
///
/// A parameter records itself both when it's created and when it's read, so parameters stored in
/// a geometry are found even if the model never reads them with its default values, and
/// parameters declared as local variables in a `body` are found when it runs.
///
/// Each geometry's `body` records into a recorder of its own, whose parameters go into the
/// geometry's result as a ``ParameterList``, which keeps them in the order of the code rather than
/// the order the build happens to run in. Everything recorded below the recorder a build started
/// with also goes to that one, so a parameter whose result an operation drops is still found.
internal final class ParameterRecorder: Sendable {
    @TaskLocal static var current: ParameterRecorder? = nil

    /// The recorder the build started with, or nil if this is the one
    private let root: ParameterRecorder?
    private let state = Mutex<(keys: Set<String>, parameters: [ParameterDescriptor])>(([], []))

    init() {
        root = nil
    }

    private init(root: ParameterRecorder) {
        self.root = root
    }

    /// A recorder for part of the build, whose parameters also go to the one the build started with
    func nested() -> ParameterRecorder {
        ParameterRecorder(root: root ?? self)
    }

    /// Records a parameter. Every use of one declaration is one parameter, described the first way
    /// it's recorded.
    func record(_ descriptor: ParameterDescriptor) {
        add(descriptor)
        root?.add(descriptor)
    }

    private func add(_ descriptor: ParameterDescriptor) {
        state.withLock { state in
            guard state.keys.insert(descriptor.key).inserted else { return }
            state.parameters.append(descriptor)
        }
    }

    var parameters: [ParameterDescriptor] {
        state.withLock { $0.parameters }
    }

    /// Builds a geometry's body, putting the parameters it uses into the result, ahead of the ones
    /// of the geometry it contains. Nothing is recorded unless a build is recording.
    static func recordingBody<D: Dimensionality>(_ build: () async throws -> BuildResult<D>) async rethrows -> BuildResult<D> {
        guard let current else { return try await build() }
        let recorder = current.nested()
        let result = try await $current.withValue(recorder) { try await build() }
        let parameters = recorder.parameters
        guard !parameters.isEmpty else { return result }
        return result.mergingElements([ObjectIdentifier(ParameterList.self): ParameterList(parameters)])
    }
}

/// The parameters a geometry and everything in it uses, in the order of the code: each geometry's
/// own, then the ones of the geometry it contains, in order. Every use of one declaration is one
/// parameter, described the first way it appears.
internal struct ParameterList: ResultElement {
    let parameters: [ParameterDescriptor]

    init() {
        parameters = []
    }

    init(_ parameters: [ParameterDescriptor]) {
        self.parameters = parameters
    }

    init(combining lists: [ParameterList]) {
        var keys = Set<String>()
        parameters = lists.flatMap(\.parameters).filter { keys.insert($0.key).inserted }
    }

    /// Lists, combined in order
    static func merging(_ lists: [ParameterDescriptor]...) -> [ParameterDescriptor] {
        ParameterList(combining: lists.map(ParameterList.init)).parameters
    }
}

/// The parameters of every model in a project, collected for a customizer.
///
/// While a catalog is current, models record their parameters into it instead of being evaluated
/// and written.
internal final class ParameterCatalog: Sendable {
    @TaskLocal static var current: ParameterCatalog? = nil

    /// Where the model being built is declared: its index in the project's content, followed by its
    /// index in each group it's in. Models are built concurrently, so a customizer lists them in
    /// this order rather than the order they finish in.
    @TaskLocal static var position: [Int] = []

    private let models = Mutex<[Model]>([])
    private let projectMetadata = Mutex<Metadata?>(nil)

    /// A model's parameters, with the title and description from its metadata for a customizer
    /// to show.
    struct Model: Sendable, Encodable {
        let name: String
        let title: String?
        let description: String?
        /// The names of the groups the model is in, outermost first, which a customizer can list
        /// it under
        let groups: [String]
        let parameters: [ParameterDescriptor]
        let position: [Int]

        private enum CodingKeys: String, CodingKey {
            case name, title, description, groups, parameters
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
            if !groups.isEmpty { try container.encode(groups, forKey: .groups) }
            try container.encode(parameters, forKey: .parameters)
        }
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
            let buildables: [any ModelBuildable] = directives.compactMap { $0.group ?? $0.model }
            let context = EvaluationContext()
            _ = await buildables.enumerated().asyncMap { index, buildable in
                await $position.withValue([index]) {
                    await buildable.build(environment: environment, context: context, options: options, URL: nil, filterPath: [])
                }
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
            models: models.withLock { $0 }.sorted { $0.position.lexicographicallyPrecedes($1.position) }
        ))
    }
}

extension ParameterDescriptor: Encodable {
    private enum CodingKeys: String, CodingKey {
        case key, label, type, options, unit, description
        case defaultValue = "default", minimum, maximum, step
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
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
        try container.encodeIfPresent(unit, forKey: .unit)
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
