import Foundation
#if canImport(simd)
import simd
#endif

/// An `AffineTransform2D` represents a 2D affine transformation using a 3x3 matrix.
public struct AffineTransform2D: Equatable {
    private var matrix: Matrix3x3

    internal init(_ matrix: Matrix3x3) {
        self.matrix = matrix
    }

    /// Creates an `AffineTransform2D` with the specified 3x3 matrix.
    ///
    /// - Parameter values: A 2D array of `Double` with 3x3 elements in row-major order.
    public init(_ values: [[Double]]) {
        precondition(
            values.count == 3 && values.allSatisfy { $0.count == 3},
            "AffineTransform2D requires 9 (3 x 3) elements"
        )
        self.matrix = .init(rows: values.map(Matrix3x3.Row.init))
    }

    /// Retrieves or sets the value at the given row and column indices in the 2D affine transformation matrix.
    ///
    /// - Parameters:
    ///   - row: The row index (0 to 2).
    ///   - column: The column index (0 to 2).
    public subscript(_ row: Int, _ column: Int) -> Double {
        get {
            assert((0...2).contains(row), "Row index out of range")
            assert((0...2).contains(column), "Column index out of range")
            return matrix[column, row]
        }
        set {
            assert((0...2).contains(row), "Row index out of range")
            assert((0...2).contains(column), "Column index out of range")
            matrix[column, row] = newValue
        }
    }

    /// The identity `AffineTransform2D`, representing no transformation.
    public static var identity: AffineTransform2D {
        AffineTransform2D(Matrix3x3.identity)
    }

    /// Concatenates this `AffineTransform2D` with another, creating a new combined 2D transformation.
    ///
    /// - Parameter other: The `AffineTransform2D` to concatenate with.
    public func concatenated(with other: AffineTransform2D) -> AffineTransform2D {
        AffineTransform2D(other.matrix * matrix)
    }

    /// Creates a new `AffineTransform2D` by setting a value at the given row and column indices.
    ///
    /// - Parameters:
    ///   - row: The row index (0 to 2).
    ///   - column: The column index (0 to 2).
    ///   - value: The value to set at the specified row and column.
    /// - Returns: A new `AffineTransform2D` with the specified value set.
    public func setting(row: Int, column: Int, to value: Double) -> Self {
        var transform = self
        transform[row, column] = value
        return transform
    }

    public var inverse: AffineTransform2D {
        .init(matrix.inverse)
    }

    public func applying(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> AffineTransform2D {
        .init(
            (0..<3).map { row in
                (0..<3).map { column in
                    function(row, column, self[row, column])
                }
            }
        )
    }

    public static func linearInterpolation(_ from: AffineTransform2D, _ to: AffineTransform2D, factor: Double) -> AffineTransform2D {
        from.applying { row, column, value in
            value + (to[row, column] - value) * factor
        }
    }
}

extension AffineTransform2D {
    /// Creates a translation `AffineTransform2D` using the given x and y offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    public static func translation(x: Double = 0, y: Double = 0) -> AffineTransform2D {
        var transform = identity
        transform[0, 2] = x
        transform[1, 2] = y
        return transform
    }

    /// Creates a translation `AffineTransform2D` using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the translation along x and y axes.
    public static func translation(_ v: Vector2D) -> AffineTransform2D {
        translation(x: v.x, y: v.y)
    }

    /// Creates a scaling `AffineTransform2D` using the given x and y scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    public static func scaling(x: Double = 1, y: Double = 1) -> AffineTransform2D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        return transform
    }

    /// Creates a scaling `AffineTransform2D` using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the scaling along x and y axes.
    public static func scaling(_ v: Vector2D) -> AffineTransform2D {
        scaling(x: v.x, y: v.y)
    }

    /// Creates a rotation `AffineTransform2D` using the given angle for rotation.
    ///
    /// - Parameter angle: The rotation angle.
    public static func rotation(_ angle: Angle) -> AffineTransform2D {
        var transform = identity
        transform[0, 0] = cos(angle)
        transform[0, 1] = -sin(angle)
        transform[1, 0] = sin(angle)
        transform[1, 1] = cos(angle)
        return transform
    }

    /// Creates a shearing `AffineTransform2D` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - factor: The shearing factor.
    public static func shearing(_ axis: Axis2D, factor: Double) -> AffineTransform2D {
        var transform = AffineTransform2D.identity
        if axis == .x {
            transform[1, 0] = factor
        } else {
            transform[0, 1] = factor
        }
        return transform
    }

    /// Creates a shearing `AffineTransform2D` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - angle: The angle of shearing.
    public static func shearing(_ axis: Axis2D, angle: Angle) -> AffineTransform2D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, factor: factor)
    }
}

extension AffineTransform2D {
    /// Creates a new `AffineTransform2D` by concatenating a translation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    public func translated(x: Double = 0, y: Double = 0) -> AffineTransform2D {
        concatenated(with: .translation(x: x, y: y))
    }

    /// Creates a new `AffineTransform2D` by concatenating a translation with this transformation using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the translation along x and y axes.
    public func translated(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .translation(v))
    }

    /// Creates a new `AffineTransform2D` by concatenating a scaling transformation with this transformation using the given 2D vector.
    ///
    /// - Parameter v: The 2D vector representing the scaling along x and y axes.
    public func scaled(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .scaling(v))
    }

    /// Creates a new `AffineTransform2D` by concatenating a scaling transformation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    public func scaled(x: Double = 1, y: Double = 1) -> AffineTransform2D {
        concatenated(with: .scaling(x: x, y: y))
    }

    /// Creates a new `AffineTransform2D` by concatenating a rotation transformation with this transformation.
    ///
    /// - Parameter angle: The rotation angle.
    public func rotated(_ angle: Angle) -> AffineTransform2D {
        concatenated(with: .rotation(angle))
    }

    /// Creates a new `AffineTransform2D` by concatenating a shearing transformation with this transformation.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - factor: The shearing factor.
    public func sheared(_ axis: Axis2D, factor: Double) -> AffineTransform2D {
        concatenated(with: .shearing(axis, factor: factor))
    }

    /// Creates a new `AffineTransform2D` by concatenating a shearing transformation with this transformation at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - angle: The angle of shearing.
    public func sheared(_ axis: Axis2D, angle: Angle) -> AffineTransform2D {
        concatenated(with: .shearing(axis, angle: angle))
    }
}

extension AffineTransform2D {
    /// Applies the affine transformation to a 2D point, returning the transformed point.
    ///
    /// - Parameter point: The 2D point to transform.
    /// - Returns: The transformed 2D point.
    public func apply(to point: Vector2D) -> Vector2D {
        return Vector2D(matrixColumn: matrix * point.matrixColumn)
    }
}

extension AffineTransform2D {
    /// Creates a new `AffineTransform2D` by converting a 3D affine transformation to 2D, discarding Z components.
    ///
    /// - Parameter transform3d: The 3D affine transformation to convert.
    public init(_ transform3d: AffineTransform3D) {
        self = .identity

        self[0, 0] = transform3d[0, 0]
        self[0, 1] = transform3d[0, 1]
        self[1, 0] = transform3d[1, 0]
        self[1, 1] = transform3d[1, 1]

        self[0, 2] = transform3d[0, 3]
        self[1, 2] = transform3d[1, 3]
    }
}

internal extension Vector2D {
    var matrixColumn: Matrix3x3.Column {
        .init(x, y, 1.0)
    }

    init(matrixColumn v: Matrix3x3.Column) {
        self.init(x: v[0], y: v[1])
    }
}
