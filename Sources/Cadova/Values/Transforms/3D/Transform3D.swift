import Foundation
#if canImport(simd)
import simd
#endif

/// An `Transform3D` represents a 3D affine transformation using a 4x4 matrix.
public struct Transform3D: Transform {
    public typealias D = D3
    private var matrix: Matrix4x4

    public static let size = (rows: 4, columns: 4)

    private init(_ matrix: Matrix4x4) {
        self.matrix = matrix
    }

    /// Creates an `Transform3D` with the specified 4x4 matrix.
    ///
    /// - Parameter values: A 2D array of `Double` with 4x4 elements in row-major order.
    public init(_ values: [[Double]]) {
        precondition(
            values.count == 4 && values.allSatisfy { $0.count == 4 },
            "Transform3D requires 16 (4 x 4) elements"
        )
        self.init(Matrix4x4(rows: values.map(Matrix4x4.Row.init)))
    }

    /// Retrieves or sets the value at the given row and column indices in the affine transformation matrix.
    ///
    /// - Parameters:
    ///   - row: The row index (0 to 3).
    ///   - column: The column index (0 to 3).
    public subscript(_ row: Int, _ column: Int) -> Double {
        get {
            assert((0...3).contains(row), "Row index out of range")
            assert((0...3).contains(column), "Column index out of range")
            return matrix[column, row]
        }
        set {
            assert((0...3).contains(row), "Row index out of range")
            assert((0...3).contains(column), "Column index out of range")
            matrix[column, row] = newValue
        }
    }

    /// The identity `Transform3D`, representing no transformation.
    public static var identity: Transform3D {
        Transform3D(Matrix4x4.identity)
    }

    /// Concatenates this `Transform3D` with another, creating a new combined transformation.
    ///
    /// - Parameter other: The `Transform3D` to concatenate with.
    public func concatenated(with other: Transform3D) -> Transform3D {
        Transform3D(other.matrix * matrix)
    }

    /// Computes the inverse of the affine transformation, if possible.
    ///
    /// - Returns: The inverse `Transform3D`, which, when concatenated with the original transform, results in the
    /// identity transform. If the matrix is not invertible, the behavior is undefined.
    public var inverse: Transform3D {
        .init(matrix.inverse)
    }

    /// Applies a custom transformation function to each element of the matrix.
    ///
    /// - Parameter function: A transformation function that takes row and column indices, along with the current
    ///   value, and returns a new value.
    /// - Returns: A new `Transform3D` with the function applied to each element of the matrix.
    public func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Transform3D {
        .init(
            (0..<4).map { row in
                (0..<4).map { column in
                    function(row, column, self[row, column])
                }
            }
        )
    }
}

public extension Transform3D {
    /// Creates a new `Transform3D` from a 2D affine transformation.
    ///
    /// - Parameter transform2d: The 2D affine transformation to convert.
    init(_ transform2d: Transform2D) {
        var transform = Transform3D.identity

        transform[0, 0] = transform2d[0, 0]
        transform[0, 1] = transform2d[0, 1]
        transform[1, 0] = transform2d[1, 0]
        transform[1, 1] = transform2d[1, 1]
        
        transform[0, 3] = transform2d[0, 2]
        transform[1, 3] = transform2d[1, 2]
        
        self = transform
    }

    /// Applies the affine transformation to a 3D point, returning the transformed point.
    ///
    /// - Parameter point: The 3D point to transform.
    /// - Returns: The transformed 3D point.
    func apply(to point: Vector3D) -> Vector3D {
        return Vector3D(matrixColumn: matrix * point.matrixColumn)
    }

    /// The offset of the transformation, defined as the result of applying the affine transformation to the origin
    /// point
    ///
    /// This property represents the transformed position of the origin after applying the full affine transformation,
    /// including translation, rotation, scaling, and other effects. It effectively shows where the origin of the
    /// coordinate space is mapped in the transformed space.
    ///
    var offset: Vector3D {
        apply(to: .zero)
    }

    init(_ transform3d: Transform3D) {
        self = transform3d
    }
}

extension Transform3D {
    public var transform3D: Transform3D {
        self
    }
}

internal extension Vector3D {
    var matrixColumn: Matrix4x4.Column {
        .init(x, y, z, 1.0)
    }

    init(matrixColumn v: Matrix4x4.Column) {
        self.init(v[0], v[1], v[2])
    }
}
