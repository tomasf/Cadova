import Foundation

internal struct CommandLineArguments {
    @TaskLocal static var overriddenArguments: [String]? = nil

    static var current: CommandLineArguments {
        CommandLineArguments(arguments: overriddenArguments ?? CommandLine.arguments)
    }

    /// Model names specified via `--model NAME` or `--model=NAME`, or empty if none were specified.
    let modelFilter: Set<String>

    /// Parameter overrides specified via `--param name=value` or `--param=name=value`.
    let parameters: [String: String]

    /// Whether `--list-parameters` was given, asking for the models' parameters as JSON instead
    /// of building them.
    let listsParameters: Bool

    /// The file given with `--list-parameters=PATH` to write the parameters to, in place of
    /// standard output.
    let parameterListPath: String?

    /// The directory given with `--output DIR` or `--output=DIR`, which models are saved to in
    /// place of the project's own output directory.
    let outputDirectory: String?

    init(arguments: [String]) {
        let args = Array(arguments.dropFirst()) // drop executable path
        var filters: Set<String> = []
        var parameters: [String: String] = [:]
        var listsParameters = false
        var parameterListPath: String?
        var outputDirectory: String?

        // Reads the value for a flag accepting both `--flag value` and `--flag=value` forms,
        // advancing the index past a separate value argument.
        func value(for flag: String, at index: inout Int) -> String? {
            let arg = args[index]
            if arg.hasPrefix("\(flag)=") {
                return String(arg.dropFirst(flag.count + 1))
            } else if arg == flag, index + 1 < args.count {
                index += 1
                return args[index]
            }
            return nil
        }

        var i = 0
        while i < args.count {
            if args[i] == "--list-parameters" {
                listsParameters = true
            } else if args[i].hasPrefix("--list-parameters=") {
                listsParameters = true
                parameterListPath = String(args[i].dropFirst("--list-parameters=".count))
            } else if let directory = value(for: "--output", at: &i) {
                outputDirectory = directory
            } else if let name = value(for: "--model", at: &i) {
                filters.insert(name)
            } else if let assignment = value(for: "--param", at: &i) {
                let parts = assignment.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    parameters[String(parts[0])] = String(parts[1])
                } else {
                    logger.warning("Ignoring malformed argument \"--param \(assignment)\". Expected the form name=value.")
                }
            }
            i += 1
        }

        modelFilter = filters
        self.parameters = parameters
        self.listsParameters = listsParameters
        self.parameterListPath = parameterListPath
        self.outputDirectory = outputDirectory
    }
}
