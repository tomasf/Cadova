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

extension RangeExpression {
    var min: Bound? {
        switch self {
        case let self as ClosedRange<Bound>: self.lowerBound
        case let self as Range<Bound>: self.lowerBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound
        default: nil
        }
    }

    var max: Bound? {
        switch self {
        case let self as ClosedRange<Bound>: self.upperBound
        case let self as Range<Bound>: self.upperBound
        case let self as PartialRangeThrough<Bound>: self.upperBound
        case let self as PartialRangeUpTo<Bound>: self.upperBound
        default: nil
        }
    }
}
