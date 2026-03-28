import Foundation

internal struct CommandLineArguments {
    static let current = CommandLineArguments()

    /// Model names passed as positional arguments, or empty if none were specified.
    let modelFilter: Set<String>

    private init() {
        let args = CommandLine.arguments.dropFirst() // drop executable path
        modelFilter = Set(args.filter { !$0.hasPrefix("-") })
    }
}
