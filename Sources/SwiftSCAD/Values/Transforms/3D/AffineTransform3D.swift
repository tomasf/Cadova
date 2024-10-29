import Foundation
#if canImport(simd)
import simd
#endif

/// An `AffineTransform3D` represents a 3D affine transformation using a 4x4 matrix.
public struct AffineTransform3D: AffineTransform, Equatable, Sendable {
    private var matrix: Matrix4x4

    private init(_ matrix: Matrix4x4) {
        self.matrix = matrix
    }

    /// Creates an `AffineTransform3D` with the specified 4x4 matrix.
    ///
    /// - Parameter values: A 2D array of `Double` with 4x4 elements in row-major order.
    public init(_ values: [[Double]]) {
        precondition(
            values.count == 4 && values.allSatisfy { $0.count == 4},
            "AffineTransform3D requires 16 (4 x 4) elements"
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

    /// A 2D array representing the values of the affine transformation.
    public var values: [[Double]] {
        (0...3).map { row in
            (0...3).map { column in
                self[row, column]
            }
        }
    }

    /// The identity `AffineTransform3D`, representing no transformation.
    public static var identity: AffineTransform3D {
        AffineTransform3D(Matrix4x4.identity)
    }

    /// Concatenates this `AffineTransform3D` with another, creating a new combined transformation.
    ///
    /// - Parameter other: The `AffineTransform3D` to concatenate with.
    public func concatenated(with other: AffineTransform3D) -> AffineTransform3D {
        AffineTransform3D(other.matrix * matrix)
    }

    /// Computes the inverse of the affine transformation, if possible.
    ///
    /// - Returns: The inverse `AffineTransform3D`, which, when concatenated with the original transform, results in the identity transform. If the matrix is not invertible, the behavior is undefined.
    public var inverse: AffineTransform3D {
        .init(matrix.inverse)
    }

    /// Applies a custom transformation function to each element of the matrix.
    ///
    /// - Parameter function: A transformation function that takes row and column indices, along with the current value, and returns a new value.
    /// - Returns: A new `AffineTransform3D` with the function applied to each element of the matrix.
    public func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> AffineTransform3D {
        .init(
            (0..<4).map { row in
                (0..<4).map { column in
                    function(row, column, self[row, column])
                }
            }
        )
    }
}

public extension AffineTransform3D {
    /// Creates a new `AffineTransform3D` from a 2D affine transformation.
    ///
    /// - Parameter transform2d: The 2D affine transformation to convert.
    init(_ transform2d: AffineTransform2D) {
        var transform = AffineTransform3D.identity

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

    init(_ transform3d: AffineTransform3D) {
        self = transform3d
    }
}

extension AffineTransform3D: AffineTransformInternal {
    var transform3D: AffineTransform3D {
        self
    }
}

extension AffineTransform3D: SCADValue {
    public var scadString: String {
        values.scadString
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
