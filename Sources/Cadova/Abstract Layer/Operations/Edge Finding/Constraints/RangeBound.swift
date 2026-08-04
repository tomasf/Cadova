import Foundation

/// A Hashable & Codable representation of a plain numeric range.
///
/// Stands in for `any WithinRange` so that `EdgeQuery` can be used as a cache key. Used both
/// for a range along a specific axis and for scalar ranges like edge length.
internal struct RangeBound: Hashable, Codable, Sendable {
    let lower: Double?   // nil = -∞
    let upper: Double?   // nil = +∞

    func contains(_ value: Double) -> Bool {
        (lower.map { value >= $0 } ?? true) && (upper.map { value <= $0 } ?? true)
    }

    init(_ range: some WithinRange) {
        switch range {
        case let range as ClosedRange<Double>:         lower = range.lowerBound; upper = range.upperBound
        case let range as Range<Double>:               lower = range.lowerBound; upper = range.upperBound
        case let range as PartialRangeFrom<Double>:    lower = range.lowerBound; upper = nil
        case let range as PartialRangeThrough<Double>: lower = nil;              upper = range.upperBound
        case let range as PartialRangeUpTo<Double>:    lower = nil;              upper = range.upperBound
        default:                                       lower = nil;              upper = nil
        }
    }
}
