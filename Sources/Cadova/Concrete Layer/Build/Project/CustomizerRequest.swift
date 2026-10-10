import Foundation

/// What a customizer asks of a model executable it runs.
///
/// A customizer, such as the page that `swift package generate-customizer` builds, starts the model
/// executable with `CADOVA_CUSTOMIZER_REQUEST` set to the path of a JSON file describing what it
/// wants: either every model's parameters, or one model built with the values its visitor chose.
/// This is a contract between Cadova and its customizer page, not a public interface.
internal struct CustomizerRequest: Decodable, Sendable {
    /// Where to write every model's parameters as JSON, instead of building any models.
    let parameterListPath: String?

    /// The model to build.
    let model: String?

    /// Parameter values for the model, by label, written as ``ParameterValue/init(parameterString:)``
    /// reads them.
    let values: [String: String]

    /// The directory to write models to, in place of the project's own.
    let outputDirectory: String?

    private enum CodingKeys: String, CodingKey {
        case parameterListPath = "listParameters", model, values, outputDirectory = "output"
    }

    init(parameterListPath: String? = nil, model: String? = nil, values: [String: String] = [:], outputDirectory: String? = nil) {
        self.parameterListPath = parameterListPath
        self.model = model
        self.values = values
        self.outputDirectory = outputDirectory
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parameterListPath = try container.decodeIfPresent(String.self, forKey: .parameterListPath)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        values = try container.decodeIfPresent([String: String].self, forKey: .values) ?? [:]
        outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory)
    }

    /// Replaces the request from the environment variable, for tests.
    @TaskLocal static var overridden: CustomizerRequest? = nil

    /// The request the executable was started with, if a customizer started it.
    static var current: CustomizerRequest? {
        overridden ?? fromEnvironment
    }

    private static let fromEnvironment: CustomizerRequest? = {
        guard let path = ProcessInfo.processInfo.environment["CADOVA_CUSTOMIZER_REQUEST"] else { return nil }
        do {
            return try JSONDecoder().decode(CustomizerRequest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        } catch {
            logger.error("Failed to read the customizer request \(path): \(error.descriptiveString)")
            exit(EXIT_FAILURE)
        }
    }()
}
