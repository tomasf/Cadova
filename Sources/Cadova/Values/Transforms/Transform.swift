import Foundation

public protocol Transform: Sendable, Hashable, Codable, Transformable where T == Self, Transformed == Self {
    associatedtype D: Dimensionality
    typealias V = D.Vector

    static var identity: Self { get }

    var inverse: Self { get }
    var offset: V { get }
    func concatenated(with: Self) -> Self
    static func *(_ lhs: Self, _ rhs: Self) -> Self
    func apply(to point: V) -> V

    func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Self
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self

    init(_ values: [[Double]])
    subscript(_ row: Int, _ column: Int) -> Double { get set }

    static func translation(_ v: V) -> Self
    static func scaling(_ v: V) -> Self

    static var size: (rows: Int, columns: Int) { get }
    init(_ transform3D: Transform3D)
    var transform3D: Transform3D { get }

    var isIdentity: Bool { get }
    var scale: V { get }
}

public extension Transform {
    /// A 2D array representing the values of the affine transformation.
    var values: [[Double]] {
        (0..<Self.size.rows).map { row in
            (0..<Self.size.columns).map { column in
                self[row, column]
            }
        }
    }

    /// Performs linear interpolation between two affine transformations.
    ///
    /// - Parameters:
    ///   - from: The starting transform.
    ///   - to: The ending transform.
    ///   - factor: The interpolation factor between 0.0 and 1.0, where 0.0 results in the `from` transform and 1.0
    ///     results in the `to` transform.
    /// - Returns: A new `Transform` representing the interpolated transformation.
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self {
        from.mapValues { row, column, value in
            value + (to[row, column] - value) * factor
        }
    }

    /// Creates a new `Transform` by concatenating a translation with this transformation using the given vector.
    ///
    /// - Parameter v: The vector representing the translation along each axis.
    func translated(_ v: V) -> Self {
        concatenated(with: .translation(v))
    }

    /// Creates a new `Transform` by concatenating a scaling transformation with this transformation using the
    /// given vector.
    ///
    /// - Parameter v: The vector representing the scaling along each axis.
    func scaled(_ v: V) -> Self {
        concatenated(with: .scaling(v))
    }
}

public extension Transform {
    func hash(into hasher: inout Hasher) {
        for row in (0..<Self.size.rows) {
            for column in (0..<Self.size.columns) {
                hasher.combine(self[row, column].roundedForHash)
            }
        }
    }

    static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        for row in (0..<Self.size.rows) {
            for column in (0..<Self.size.columns) {
                if lhs[row, column].roundedForHash != rhs[row, column].roundedForHash {
                    return false
                }
            }
        }
        return true
    }

    static func *(_ lhs: Self, _ rhs: Self) -> Self {
        lhs.concatenated(with: rhs)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([[Double]].self))
    }

    func transformed(_ transform: Self) -> Self {
        concatenated(with: transform)
    }
}

public extension Transform {
    /// The Frobenius norm of the transform matrix.
    ///
    /// This is defined as the square root of the sum of the squares of all entries in the
    /// underlying matrix. It provides a convenient scalar measure of the matrix’s overall
    /// magnitude and is useful for constructing relative tolerances when comparing transforms.
    ///
    var frobeniusNorm: Double {
        var acc = 0.0
        for r in 0..<Self.size.rows {
            for c in 0..<Self.size.columns {
                let v = self[r, c]
                acc += v * v
            }
        }
        return acc.squareRoot()
    }

    /// Returns true if `self` and `other` represent (nearly) the same transform.
    ///
    /// The relative term is scaled by the magnitude of `other` (its `frobeniusNorm`),
    /// with a floor of 1.0 to avoid zero-scale edge cases.
    ///
    func isApproximatelyEqual(to other: Self) -> Bool {
        let d = self.inverse.concatenated(with: other)
        var errSq = 0.0
        for r in 0..<Self.size.rows {
            for c in 0..<Self.size.columns {
                let diff = d[r, c] - (r == c ? 1.0 : 0.0)
                errSq += diff * diff
            }
        }
        return errSq.squareRoot() <= 1e-9 + max(other.frobeniusNorm, 1.0) * 1e-12
    }
}
