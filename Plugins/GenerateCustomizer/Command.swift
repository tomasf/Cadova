import Foundation

/// Runs external programs (the WebAssembly toolchain, curl, tar) for the plugin.
struct Command {
    let executable: URL
    var arguments: [String] = []
    var directory: URL? = nil
    /// Changes to the inherited environment. A nil value removes the variable.
    var environment: [String: String?] = [:]

    init(_ executable: URL, _ arguments: [String] = [], in directory: URL? = nil, environment: [String: String?] = [:]) {
        self.executable = executable
        self.arguments = arguments
        self.directory = directory
        self.environment = environment
    }

    /// Looks a program up in the standard system locations, which is where the plugin's helpers
    /// (curl, tar and a SHA-256 tool) live on macOS and Linux.
    init(system name: String, _ arguments: [String] = []) throws {
        let candidates = ["/usr/bin", "/bin", "/usr/local/bin"].map { URL(fileURLWithPath: $0).appending(path: name) }
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw CustomizerError("Couldn't find \(name), which generating a customizer needs.")
        }
        self.init(executable, arguments)
    }

    /// Runs the program, with its output going straight to the plugin's.
    func run() throws {
        let process = try makeProcess()
        try process.run()
        process.waitUntilExit()
        try check(process)
    }

    /// Runs the program and returns what it wrote to standard output.
    func output() throws -> String {
        let process = try makeProcess()
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try check(process)
        return String(decoding: data, as: UTF8.self)
    }

    private func makeProcess() throws -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var processEnvironment = ProcessInfo.processInfo.environment
        for (name, value) in environment {
            processEnvironment[name] = value
        }
        process.environment = processEnvironment
        return process
    }

    private func check(_ process: Process) throws {
        guard process.terminationStatus == 0 else {
            throw CustomizerError("\(executable.lastPathComponent) failed (exit code \(process.terminationStatus)).")
        }
    }
}

extension Command {
    /// Downloads a file and checks it against a SHA-256 checksum.
    static func download(_ url: URL, to file: URL, sha256 checksum: String) throws {
        try Command(system: "curl", ["-fL", "--progress-bar", "-o", file.path, url.absoluteString]).run()
        let actual = try sha256(of: file)
        guard actual == checksum else {
            try? FileManager.default.removeItem(at: file)
            throw CustomizerError("\(url.lastPathComponent) didn't match its checksum (expected \(checksum), got \(actual)).")
        }
    }

    /// Downloads a gzipped tarball, checks it and unpacks it into a directory.
    static func downloadArchive(_ url: URL, sha256 checksum: String, into directory: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let archive = temporary.appending(path: "download.tar.gz")
        try download(url, to: archive, sha256: checksum)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Command(system: "tar", ["xzf", archive.path, "-C", directory.path]).run()
    }

    static func sha256(of file: URL) throws -> String {
        #if os(macOS)
        let command = try Command(system: "shasum", ["-a", "256", file.path])
        #else
        let command = try Command(system: "sha256sum", [file.path])
        #endif
        return String(try command.output().prefix { !$0.isWhitespace })
    }
}

struct CustomizerError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
