#if canImport(AppKit)
import AppKit
#endif

struct OpenSCADExport {
    let inputCode: Data
    let outputFormat: any OutputFormat

    func run() throws -> Data {
        guard let formatString = outputFormat.openSCADTypeString else {
            preconditionFailure("Output format isn't valid for export")
        }

        guard let openSCAD = Self.executableURL() else {
            throw RunError.noExecutable
        }

        let inputPipe = Pipe()
        inputPipe.fileHandleForWriting.write(inputCode)
        try inputPipe.fileHandleForWriting.close()

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let process = Process()
        process.executableURL = openSCAD
        process.arguments = [
            "-o", "-", // Write to stdout
            "--export-format", formatString,
            "--enable", "all", // Enable all "experimental" features, such as manifold
            "-" // Read from stdin
        ]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = try? errorPipe.fileHandleForReading.readToEnd()
            let errorString = errorData.flatMap { String(data: $0, encoding: .utf8) }
            throw RunError.processFailed(Int(process.terminationStatus), errorString ?? "")
        }

        guard let data = try outputPipe.fileHandleForReading.readToEnd() else {
            throw RunError.noData
        }
        return data
    }

    enum RunError: LocalizedError {
        case noExecutable
        case processFailed (Int, String)
        case noData

        var errorDescription: String? {
            switch self {
            case .noExecutable:
                "OpenSCAD was not found. Use the \(OpenSCADExport.executableEnvironmentVariableName) environment variable to set the path to the executable."
            case .processFailed (let code, let info):
                "Running OpenSCAD failed with code \(code): \(info)"
            case .noData:
                "Running OpenSCAD failed. No data was returned."
            }
        }
    }
}

private extension OpenSCADExport {
    static func findExecutableAutomatically() -> URL? {
#if canImport(AppKit)
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.openscad.OpenSCAD") else {
            return nil
        }

        return Bundle(url: bundleURL)?.executableURL
#else
        return nil
#endif
    }

    static let executableEnvironmentVariableName = "OPENSCAD"

    static func executableURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment[executableEnvironmentVariableName] {
            return URL(filePath: path)
        }

        return findExecutableAutomatically()
    }
}
