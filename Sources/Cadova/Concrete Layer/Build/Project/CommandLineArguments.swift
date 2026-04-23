import Foundation

internal struct CommandLineArguments {
    @TaskLocal static var overriddenArguments: [String]? = nil

    static var current: CommandLineArguments {
        CommandLineArguments(arguments: overriddenArguments ?? CommandLine.arguments)
    }

    /// Model names specified via `--model NAME` or `--model=NAME`, or empty if none were specified.
    let modelFilter: Set<String>

    init(arguments: [String]) {
        let args = Array(arguments.dropFirst()) // drop executable path
        let flag = "--model"
        let prefix = "\(flag)="
        var filters: Set<String> = []
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix(prefix) {
                filters.insert(String(arg.dropFirst(prefix.count)))
            } else if arg == flag, i + 1 < args.count {
                filters.insert(args[i + 1])
                i += 1
            }
            i += 1
        }
        modelFilter = filters
    }
}
