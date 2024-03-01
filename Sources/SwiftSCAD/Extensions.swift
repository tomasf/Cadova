import Foundation

extension Sequence {
    func paired() -> [(Element, Element)] {
        .init(zip(self, dropFirst()))
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
