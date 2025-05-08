import Foundation
#if canImport(simd)
import simd
#endif

/// An `Transform2D` represents a 2D affine transformation using a 3x3 matrix.
public struct Transform2D: Transform {
    public typealias D = D2
    private var matrix: Matrix3x3

    public static let size = (rows: 3, columns: 3)

    internal init(_ matrix: Matrix3x3) {
        self.matrix = matrix
    }

    /// Creates an `Transform2D` with the specified 3x3 matrix.
    ///
    /// - Parameter values: A 2D array of `Double` with 3x3 elements in row-major order.
    public init(_ values: [[Double]]) {
        precondition(
            values.count == 3 && values.allSatisfy { $0.count == 3},
            "Transform2D requires 9 (3 x 3) elements"
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

    /// The identity `Transform2D`, representing no transformation.
    public static var identity: Transform2D {
        Transform2D(Matrix3x3.identity)
    }

    /// Concatenates this `Transform2D` with another, creating a new combined 2D transformation.
    ///
    /// - Parameter other: The `Transform2D` to concatenate with.
    public func concatenated(with other: Transform2D) -> Transform2D {
        Transform2D(other.matrix * matrix)
    }

    /// Returns the inverse of this affine transform, if it exists.
    ///
    /// The inverse transform reverses the effects of applying this transform. If the transform is non-invertible, the result is undefined.
    public var inverse: Transform2D {
        .init(matrix.inverse)
    }

    /// Applies a custom function to each element of the matrix, creating a new `Transform2D`.
    ///
    /// This method allows for arbitrary transformations of the affine transform's underlying matrix by applying a provided function to each element.
    ///
    /// - Parameter function: A closure that takes a row index, a column index, and the current value at that position, then returns a new value to be assigned to that position.
    /// - Returns: A new `Transform2D` with the matrix modified by the provided function.
    public func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Transform2D {
        .init(
            (0..<3).map { row in
                (0..<3).map { column in
                    function(row, column, self[row, column])
                }
            }
        )
    }
}

public extension Transform2D {
    /// Applies the affine transformation to a 2D point, returning the transformed point.
    ///
    /// - Parameter point: The 2D point to transform.
    /// - Returns: The transformed 2D point.
    func apply(to point: Vector2D) -> Vector2D {
        return Vector2D(matrixColumn: matrix * point.matrixColumn)
    }

    /// The offset of the transformation, defined as the result of applying the affine transformation to the origin point
    ///
    /// This property represents the transformed position of the origin after applying
    /// the full affine transformation, including translation, rotation, scaling, and other effects.
    /// It effectively shows where the origin of the coordinate space is mapped in the transformed space.
    ///
    var offset: Vector2D {
        apply(to: .zero)
    }

    /// Creates a new `Transform2D` by converting a 3D affine transformation to 2D, discarding Z components.
    ///
    /// - Parameter transform3d: The 3D affine transformation to convert.
    init(_ transform3d: Transform3D) {
        self = .identity

        self[0, 0] = transform3d[0, 0]
        self[0, 1] = transform3d[0, 1]
        self[1, 0] = transform3d[1, 0]
        self[1, 1] = transform3d[1, 1]

        self[0, 2] = transform3d[0, 3]
        self[1, 2] = transform3d[1, 3]
    }
}

extension Transform2D {
    public var transform3D: Transform3D {
        .init(self)
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
