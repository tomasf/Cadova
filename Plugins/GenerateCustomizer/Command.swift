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
    /// (curl, tar and a SHA-256 tool) live: System32 on Windows, which has had curl and tar since
    /// Windows 10.
    init(system name: String, _ arguments: [String] = []) throws {
        #if os(Windows)
        let systemRoot = ProcessInfo.processInfo.environment["SystemRoot"] ?? #"C:\Windows"#
        let candidates = [URL(fileURLWithPath: systemRoot).appending(path: "System32/\(name).exe")]
        #else
        let candidates = ["/usr/bin", "/bin", "/usr/local/bin"].map { URL(fileURLWithPath: $0).appending(path: name) }
        #endif
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
        try Command(system: "curl", ["-fL", "--progress-bar", "-o", file.fileSystemPath, url.absoluteString]).run()
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
        try Command(system: "tar", ["xzf", archive.fileSystemPath, "-C", directory.fileSystemPath]).run()
    }

    static func sha256(of file: URL) throws -> String {
        #if os(Windows)
        // certutil prints a heading, the hash on a line of its own, and a completion message
        let output = try Command(system: "certutil", ["-hashfile", file.fileSystemPath, "SHA256"]).output()
        let lines = output.split(whereSeparator: \.isNewline)
        guard lines.count >= 2 else { throw CustomizerError("certutil didn't print a checksum for \(file.lastPathComponent).") }
        return lines[1].filter { !$0.isWhitespace }.lowercased()
        #elseif os(macOS)
        let command = try Command(system: "shasum", ["-a", "256", file.fileSystemPath])
        return String(try command.output().prefix { !$0.isWhitespace })
        #else
        let command = try Command(system: "sha256sum", [file.fileSystemPath])
        return String(try command.output().prefix { !$0.isWhitespace })
        #endif
    }
}

extension URL {
    /// The path in the platform's own form, for passing to other programs. On Windows, that has
    /// backslashes, where `path` has forward slashes and `path(percentEncoded:)` a leading one.
    var fileSystemPath: String {
        withUnsafeFileSystemRepresentation { String(cString: $0!) }
    }
}

struct CustomizerError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
