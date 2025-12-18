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

    /// Fast exact identity check for 4x4 affine matrix.
    public var isIdentity: Bool {
        // Diagonal == 1
        if self[0,0] != 1.0 { return false }
        if self[1,1] != 1.0 { return false }
        if self[2,2] != 1.0 { return false }
        if self[3,3] != 1.0 { return false }
        // Off-diagonals == 0
        if self[0,1] != 0.0 { return false }
        if self[0,2] != 0.0 { return false }
        if self[0,3] != 0.0 { return false }
        if self[1,0] != 0.0 { return false }
        if self[1,2] != 0.0 { return false }
        if self[1,3] != 0.0 { return false }
        if self[2,0] != 0.0 { return false }
        if self[2,1] != 0.0 { return false }
        if self[2,3] != 0.0 { return false }
        if self[3,0] != 0.0 { return false }
        if self[3,1] != 0.0 { return false }
        if self[3,2] != 0.0 { return false }
        return true
    }

    /// Per-axis scale of the linear 3×3 part (ignoring translation).
    ///
    /// Computed as the Euclidean norms of the three column vectors of the upper-left 3×3 submatrix.
    /// For the identity transform, this is [1, 1, 1].
    ///
    /// Notes:
    /// - If the transform contains shear, these values are approximations based on column norms.
    /// - Reflections are handled via absolute magnitudes.
    public var scale: Vector3D {
        if isIdentity { return Vector3D(1, 1, 1) }

        let c0x = self[0,0], c0y = self[1,0], c0z = self[2,0]
        let c1x = self[0,1], c1y = self[1,1], c1z = self[2,1]
        let c2x = self[0,2], c2y = self[1,2], c2z = self[2,2]

        let sx = sqrt(c0x * c0x + c0y * c0y + c0z * c0z)
        let sy = sqrt(c1x * c1x + c1y * c1y + c1z * c1z)
        let sz = sqrt(c2x * c2x + c2y * c2y + c2z * c2z)

        return Vector3D(sx, sy, sz)
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
