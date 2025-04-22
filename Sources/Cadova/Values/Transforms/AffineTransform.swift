import Foundation

public protocol AffineTransform: Sendable, Hashable, Codable {
    associatedtype D: Dimensionality
    typealias V = D.Vector
    associatedtype Rotation

    static var identity: Self { get }

    var inverse: Self { get }
    var offset: V { get }
    func concatenated(with: Self) -> Self
    func apply(to point: V) -> V

    func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Self
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self

    init(_ values: [[Double]])
    subscript(_ row: Int, _ column: Int) -> Double { get set }

    static func translation(_ v: V) -> Self
    static func scaling(_ v: V) -> Self
    static func rotation(_ r: Rotation) -> Self
    
    func translated(_ v: V) -> Self
    func scaled(_ v: V) -> Self
    func rotated(_ rotation: Rotation) -> Self

    static var size: (rows: Int, columns: Int) { get }
    init(_ transform3D: AffineTransform3D)
    var transform3D: AffineTransform3D { get }
}

public extension AffineTransform {
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
    ///   - factor: The interpolation factor between 0.0 and 1.0, where 0.0 results in the `from` transform and 1.0 results in the `to` transform.
    /// - Returns: A new `AffineTransform` representing the interpolated transformation.
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self {
        from.mapValues { row, column, value in
            value + (to[row, column] - value) * factor
        }
    }

    /// Creates a new `AffineTransform` by concatenating a translation with this transformation using the given vector.
    ///
    /// - Parameter v: The vector representing the translation along each axis.
    func translated(_ v: V) -> Self {
        concatenated(with: .translation(v))
    }

    /// Creates a new `AffineTransform` by concatenating a scaling transformation with this transformation using the given vector.
    ///
    /// - Parameter v: The vector representing the scaling along each axis.
    func scaled(_ v: V) -> Self {
        concatenated(with: .scaling(v))
    }

    /// Creates a new `AffineTransform` by concatenating a rotation transformation with this transformation using the given rotation.
    ///
    /// - Parameter r: The rotation to apply
    func rotated(_ r: Rotation) -> Self {
        concatenated(with: .rotation(r))
    }
}

public extension AffineTransform {
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

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([[Double]].self))
    }
}
