import Foundation
import PackagePlugin

/// Builds a web customizer for a model package: a directory of static files, the page and the
/// model as WebAssembly, that can be published on any web server. Visitors set the model's
/// `@Parameter` values, see a live 3D preview and download a 3MF file.
///
///     swift package generate-customizer [--product NAME] [--model NAME] [--output DIR]
///
/// The page offers every model that has parameters, with a tab for each, unless `--model` limits it
/// to one.
/// The output goes to `Customizer` in the package unless `--output` says otherwise.
@main
struct GenerateCustomizer: CommandPlugin {
    static let usage = "usage: swift package generate-customizer [--product NAME] [--model NAME] [--output DIR]"

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var extractor = ArgumentExtractor(arguments)
        let productName = extractor.extractOption(named: "product").last
        let model = extractor.extractOption(named: "model").last
        let outputPath = extractor.extractOption(named: "output").last
        guard extractor.remainingArguments.isEmpty else {
            throw CustomizerError("Unexpected arguments: \(extractor.remainingArguments.joined(separator: " "))\n\(Self.usage)")
        }

        let package = context.package
        let product = try Self.product(named: productName, in: package)
        let output = outputPath.map { URL(fileURLWithPath: $0, relativeTo: package.directoryURL).standardizedFileURL }
            ?? package.directoryURL.appending(path: "Customizer")

        let workDirectory = context.pluginWorkDirectoryURL
        let toolchain = try WebAssemblyToolchain.prepare(in: workDirectory, support: Self.pluginDirectory.appending(path: "Support"))

        print("Building \(product.name) for WebAssembly")
        let module = try toolchain.build(
            product: product.name,
            packageDirectory: package.directoryURL,
            scratchDirectory: workDirectory.appending(path: "build")
        )

        print("Assembling the customizer in \(output.path)")
        try Self.writePage(to: output, model: model)

        print("Optimizing for size")
        let optimized = output.appending(path: "model.wasm")
        try toolchain.optimize(module, to: optimized)

        let size = (try? optimized.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? "?"
        print("Done: \(output.path) (model.wasm is \(size))")
        print("Preview with: python3 -m http.server --directory \"\(output.path)\" 8000")
    }

    /// Where the plugin's own files are: the page template and the C sources it builds into the SDK
    static var pluginDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    static func product(named name: String?, in package: Package) throws -> ExecutableProduct {
        let products = package.products(ofType: ExecutableProduct.self)
        if let name {
            guard let product = products.first(where: { $0.name == name }) else {
                throw CustomizerError("\(package.displayName) has no executable product named \(name).")
            }
            return product
        }
        guard products.count == 1, let product = products.first else {
            let names = products.map(\.name).joined(separator: ", ")
            throw CustomizerError(products.isEmpty
                ? "\(package.displayName) has no executable product to build a customizer from."
                : "\(package.displayName) has several executable products (\(names)); pick one with --product.")
        }
        return product
    }

    /// Copies the page into the output directory. A model the page is limited to is named in a
    /// `cadova-model` meta tag, which the page reads.
    static func writePage(to output: URL, model: String?) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        let template = pluginDirectory.appending(path: "Template")
        for name in try fileManager.contentsOfDirectory(atPath: template.path) {
            let destination = output.appending(path: name)
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: template.appending(path: name), to: destination)
        }

        if let model {
            let page = output.appending(path: "index.html")
            let html = try String(contentsOf: page, encoding: .utf8)
            let escaped = model
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
            let tagged = html.replacingOccurrences(
                of: "<meta name=\"viewport\"",
                with: "<meta name=\"cadova-model\" content=\"\(escaped)\">\n<meta name=\"viewport\"",
                options: [],
                range: html.range(of: "<meta name=\"viewport\"")
            )
            try tagged.write(to: page, atomically: true, encoding: .utf8)
        }
    }
}
