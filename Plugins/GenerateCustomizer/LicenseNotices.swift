import Foundation
import PackagePlugin

/// The licenses of the software a customizer is made of, which a published customizer distributes:
/// Cadova and every other package the model's executable is built from, the parts of Swift's
/// WebAssembly SDK that get linked into it, and the libraries the page loads.
///
/// Packages are read from the package graph, so a model's own dependencies are covered too. Each
/// package contributes its license files: the ones in its root directory, and the ones in or above
/// the directories of the targets the executable is built from, which is where packages keep the
/// licenses of libraries they include in source form.
struct LicenseNotices {
    struct Section {
        let title: String
        let address: String?
        let files: [File]
    }

    struct File {
        /// Where the file is within its package or SDK, or nil for a section's only file
        let name: String?
        let text: String
    }

    var sections: [Section]

    /// File names that hold licenses. FreeType keeps its own license as docs/FTL.TXT.
    private static let licenseNamePrefixes = ["license", "licence", "copying", "copyright", "notice"]
    private static let otherLicenseNames: Set<String> = ["ftl.txt"]

    /// Directories that aren't built into anything, so their licenses don't apply
    private static let skippedDirectoryNames: Set<String> = [".build", ".git", ".github", "tests", "test", "examples", "bindings"]

    /// What isn't in the package graph: the parts of Swift's WebAssembly SDK that end up in the
    /// executable, and the libraries the page loads. Their texts are in the plugin's
    /// Support/licenses. Check these when moving to another SDK or library version.
    private static let bundled: [(title: String, address: String, file: String)] = [
        ("Swift standard library and Foundation", "https://github.com/swiftlang/swift", "swift.txt"),
        ("ICU", "https://github.com/unicode-org/icu", "icu.txt"),
        ("wasi-libc", "https://github.com/WebAssembly/wasi-libc", "wasi-libc.txt"),
        ("three.js", "https://github.com/mrdoob/three.js", "three.js.txt"),
        ("browser_wasi_shim", "https://github.com/bjorn3/browser_wasi_shim", "browser_wasi_shim.txt"),
    ]

    /// Collects the licenses of everything an executable product is built from. The model's own
    /// package is left out, since its license is the model's, which the page shows from its metadata.
    static func collect(for product: ExecutableProduct, in package: Package, support: URL) throws -> Self {
        // Which package each target belongs to, across the whole graph
        var packageOfTarget: [Target.ID: Package] = [:]
        var visitedPackages: Set<Package.ID> = []
        var pendingPackages = [package]
        while let next = pendingPackages.popLast() {
            guard visitedPackages.insert(next.id).inserted else { continue }
            for target in next.targets { packageOfTarget[target.id] = next }
            pendingPackages += next.dependencies.map(\.package)
        }

        // The targets the product is built from, grouped by package in the order they're found
        var packages: [Package] = []
        var targetsByPackage: [Package.ID: [Target]] = [:]
        var visitedTargets: Set<Target.ID> = []
        func visit(_ target: Target) {
            guard visitedTargets.insert(target.id).inserted else { return }
            if let owner = packageOfTarget[target.id], owner.id != package.id {
                if targetsByPackage[owner.id] == nil { packages.append(owner) }
                targetsByPackage[owner.id, default: []].append(target)
            }
            for dependency in target.dependencies {
                switch dependency {
                case .target(let target): visit(target)
                case .product(let product): product.targets.forEach(visit)
                @unknown default: break
                }
            }
        }
        product.targets.forEach(visit)

        // Cadova first, since the page is made with it
        packages = packages.filter { $0.displayName == "Cadova" } + packages.filter { $0.displayName != "Cadova" }

        var sections = try packages.compactMap { package in
            try section(for: package, targets: targetsByPackage[package.id] ?? [])
        }
        sections += try bundled.map { title, address, file in
            Section(title: title, address: address, files: [File(name: nil, text: try readText(support.appending(path: "licenses/\(file)")))])
        }
        return Self(sections: sections)
    }

    private static func section(for package: Package, targets: [Target]) throws -> Section? {
        let root = package.directoryURL.standardizedFileURL
        var found: [URL] = licenseFiles(in: root)
        for target in targets {
            let directory = target.directoryURL.standardizedFileURL
            guard directory.path.hasPrefix(root.path) else { continue }
            found += licenseFiles(inTree: directory)
            var ancestor = directory.deletingLastPathComponent()
            while ancestor.path.count > root.path.count {
                found += licenseFiles(in: ancestor)
                ancestor = ancestor.deletingLastPathComponent()
            }
        }

        var seen: Set<String> = []
        let files = try found.filter { seen.insert($0.path).inserted }.map { file in
            let relative = String(file.path.dropFirst(root.path.count)).trimmingCharacters(in: ["/"])
            return File(name: relative, text: try readText(file))
        }
        guard !files.isEmpty else { return nil }

        let address: String? = switch package.origin {
        case .repository(let url, _, _): url
        default: nil
        }
        return Section(title: package.displayName, address: address, files: files)
    }

    private static func isLicenseFile(_ name: String) -> Bool {
        let name = name.lowercased()
        return otherLicenseNames.contains(name) || licenseNamePrefixes.contains { name.hasPrefix($0) }
    }

    /// The license files directly in a directory
    private static func licenseFiles(in directory: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.sorted().filter(isLicenseFile).map { directory.appending(path: $0) }.filter(isRegularFile)
    }

    /// The license files in a directory and the directories in it
    private static func licenseFiles(inTree directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if skippedDirectoryNames.contains(url.lastPathComponent.lowercased()) { enumerator.skipDescendants() }
            } else if isLicenseFile(url.lastPathComponent) {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private static func readText(_ file: URL) throws -> String {
        let data = try Data(contentsOf: file)
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return text.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Writes the licenses as a page of their own.
    func write(to url: URL) throws {
        func escaped(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }

        let contents = sections.enumerated().map { index, section in
            "<li><a href=\"#license-\(index)\">\(escaped(section.title))</a></li>"
        }.joined(separator: "\n")

        let body = sections.enumerated().map { index, section in
            var html = "<section id=\"license-\(index)\">\n<h2>\(escaped(section.title))</h2>\n"
            if let address = section.address {
                html += "<p class=\"address\"><a href=\"\(escaped(address))\">\(escaped(address))</a></p>\n"
            }
            for file in section.files {
                if let name = file.name { html += "<h3>\(escaped(name))</h3>\n" }
                html += "<pre>\(escaped(file.text))</pre>\n"
            }
            return html + "</section>"
        }.joined(separator: "\n")

        let page = """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Third-party licenses</title>
            <style>
              :root { color-scheme: light dark; --text: #1d1d1f; --muted: #6e6e73; --background: #ffffff; --code: #f5f5f7; }
              @media (prefers-color-scheme: dark) {
                :root { --text: #f5f5f7; --muted: #a1a1a6; --background: #1c1c1e; --code: #2c2c2e; }
              }
              body {
                margin: 0 auto; max-width: 820px; padding: 32px 16px 64px;
                font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                color: var(--text); background: var(--background);
              }
              h1 { font-size: 24px; margin: 0 0 8px; }
              h2 { font-size: 18px; margin: 40px 0 4px; }
              h3 { font-size: 13px; font-weight: 600; color: var(--muted); margin: 16px 0 6px; }
              a { color: inherit; }
              .address { margin: 0 0 8px; color: var(--muted); font-size: 13px; }
              pre {
                white-space: pre-wrap; overflow-wrap: anywhere; margin: 0; padding: 12px 14px; border-radius: 8px;
                background: var(--code); font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
              }
            </style>
            </head>
            <body>
            <h1>Third-party licenses</h1>
            <p>This customizer is built with the software below, which is distributed under these licenses.</p>
            <ul>
            \(contents)
            </ul>
            \(body)
            </body>
            </html>

            """
        try Data(page.utf8).write(to: url)
    }
}
