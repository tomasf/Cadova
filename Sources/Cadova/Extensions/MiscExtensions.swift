import Foundation

// Workaround for C++ interop importing Darwin's abs() which conflicts with Swift.abs()
@inlinable
internal func abs<T: SignedNumeric & Comparable>(_ x: T) -> T {
    Swift.abs(x)
}

@inlinable
internal func abs(_ x: Double) -> Double {
    Swift.abs(x)
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

extension Double {
    var unitClamped: Double {
        clamped(to: 0...1)
    }
}

extension Set {
    init(_ sets: Self...) {
        self = sets.reduce([]) { $0.union($1) }
    }

    static func +(lhs: Self, rhs: Element) -> Self {
        lhs.union([rhs])
    }

    static func -(lhs: Self, rhs: Element) -> Self {
        lhs.subtracting([rhs])
    }
}

extension Dictionary {
    init<S: Sequence<Key>>(keys: S, values: (Key) -> Value) {
        self.init(keys.map { ($0, values($0)) }) { $1 }
    }

    init(merging dictionaries: [Self]) {
        self = dictionaries.reduce(into: Self()) {
            $0.merge($1) { $1 }
        }
    }
}

extension URL {
    init(expandingFilePath path: String, extension requiredExtension: String? = nil, relativeTo: URL? = nil) {
        var url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: relativeTo)
        if let requiredExtension, url.pathExtension != requiredExtension {
            url.appendPathExtension(requiredExtension)
        }
        self = url
    }

    /// Finds the root of the Swift package containing this file by walking up the directory tree
    /// to the nearest ancestor containing a `Package.swift` manifest.
    ///
    /// For nested packages, this resolves to the innermost package that owns the file. Returns `nil`
    /// if no manifest is found, which happens when the file isn't part of a Swift package or the
    /// source tree isn't present at runtime.
    var packageRootURL: URL? {
        var url = standardizedFileURL.deletingLastPathComponent()
        while url.pathComponents.count > 1 {
            if url.appending(path: "Package.swift").isRegularFile {
                return url
            }
            // Stop if the path can no longer be shortened. `deletingLastPathComponent` is not
            // guaranteed to reduce the component count at every filesystem root on every platform,
            // and this loop must terminate regardless.
            let parent = url.deletingLastPathComponent()
            guard parent.pathComponents.count < url.pathComponents.count else { break }
            url = parent
        }
        return nil
    }

    /// Whether this URL points at an existing regular file, as opposed to a directory, a
    /// nonexistent path, or something unreadable.
    private var isRegularFile: Bool {
        (try? resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}

extension String {
    var simpleIdentifier: String {
        var string = lowercased()
        string = string.applyingTransform(.toLatin, reverse: false) ?? string
        string = string.applyingTransform(.stripDiacritics, reverse: false) ?? string
        string = string.replacingOccurrences(of: " ", with: "-")

        let allowedCharacters = CharacterSet(charactersIn: "a"..."z")
            .union(CharacterSet(charactersIn: "0"..."9"))
            .union(CharacterSet(charactersIn: "_-"))

        return String(string.unicodeScalars.filter { allowedCharacters.contains($0) })
    }
}

// The standard library doesn't yet declare key paths Sendable when their root and value are, so
// key paths into EnvironmentValues can't be captured by the @Sendable closures that geometry
// builders use. Remove this once the stdlib provides the conformance itself.
extension KeyPath: @unchecked @retroactive Sendable where Root: Sendable, Value: Sendable {}

extension Clock {
    func measure<T>(work: () async throws -> T, results: (Instant.Duration, T) -> Void) async rethrows -> T {
        var result: T?
        let duration = try await measure {
            result = try await work()
        }
        results(duration, result!)
        return result!
    }
}

func combinations<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    var result: [(A, B, C)] = []
    for itemA in a {
        for itemB in b {
            for itemC in c {
                result.append((itemA, itemB, itemC))
            }
        }
    }
    return result
}

func unpacked<A, B, C, D>(_ tuple: (A, (B, C, D))) -> (A, B, C, D) {
    (tuple.0, tuple.1.0, tuple.1.1, tuple.1.2)
}

func unpacked<A, B, C, D>(_ tuple: ((A, B), (C, D))) -> (A, B, C, D) {
    (tuple.0.0, tuple.0.1, tuple.1.0, tuple.1.1)
}

func unpacked<A, B, C>(_ tuple: ((A, B), C)) -> (A, B, C) {
    (tuple.0.0, tuple.0.1, tuple.1)
}

func unpacked<A, B, C>(_ tuple: (A, (B, C))) -> (A, B, C) {
    (tuple.0, tuple.1.0, tuple.1.1)
}
