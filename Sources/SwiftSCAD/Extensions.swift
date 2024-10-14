import Foundation

extension Sequence {
    func paired() -> [(Element, Element)] {
        .init(zip(self, dropFirst()))
    }

    func reduce(_ function: (Element, Element) -> Element) -> Element? {
        reduce(nil as Element?) { output, input in
            output.map { function($0, input) } ?? input
        }
    }

    func cumulativeCombination(_ function: (Element, Element) -> Element) -> [Element] {
        reduce([]) {
            if let last = $0.last { $0 + [function(last, $1)] } else { [$1] }
        }
    }
}

extension Range {
    init(_ first: Bound, _ second: Bound) {
        self.init(uncheckedBounds: (
            lower: Swift.min(first, second),
            upper: Swift.max(first, second))
        )
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

    func withRequiredExtension(_ requiredExtension: String) -> URL {
        pathExtension == requiredExtension ? self : appendingPathExtension(requiredExtension)
    }
}

extension Dictionary {
    func setting(_ key: Key, to value: Value) -> Self {
        var dict = self
        dict[key] = value
        return dict
    }
}
