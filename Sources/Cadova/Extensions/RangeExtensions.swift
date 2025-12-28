import Foundation

extension Range {
    init(_ first: Bound, _ second: Bound) {
        self.init(uncheckedBounds: (
            lower: Swift.min(first, second),
            upper: Swift.max(first, second))
        )
    }
}

extension ClosedRange {
    init(_ first: Bound, _ second: Bound) {
        self.init(uncheckedBounds: (
            lower: Swift.min(first, second),
            upper: Swift.max(first, second))
        )
    }
}

extension ClosedRange where Bound: AdditiveArithmetic {
    var length: Bound { upperBound - lowerBound }
}

extension Range where Bound: AdditiveArithmetic {
    var length: Bound { upperBound - lowerBound }
}

extension Range where Bound: FloatingPoint {
    var mid: Bound { (lowerBound + upperBound) / 2 }
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

    func resolved(with range: ClosedRange<Bound>) -> ClosedRange<Bound> {
        switch self {
        case let self as ClosedRange<Bound>: self
        case let self as Range<Bound>: self.lowerBound...self.upperBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound...range.upperBound
        case let self as PartialRangeThrough<Bound>: range.lowerBound...self.upperBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound...range.upperBound
        default: range
        }
    }
}
