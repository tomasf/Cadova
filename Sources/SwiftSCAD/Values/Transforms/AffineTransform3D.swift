import Foundation
#if canImport(simd)
import simd
#endif

/// An `AffineTransform3D` represents a 3D affine transformation using a 4x4 matrix.
public struct AffineTransform3D: AffineTransform, Equatable {
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

    /// Creates a new `AffineTransform3D` by setting a value at the given row and column indices.
    ///
    /// - Parameters:
    ///   - row: The row index (0 to 3).
    ///   - column: The column index (0 to 3).
    ///   - value: The value to set at the specified row and column.
    /// - Returns: A new `AffineTransform3D` with the specified value set.
    public func setting(row: Int, column: Int, to value: Double) -> Self {
        var transform = self
        transform[row, column] = value
        return transform
    }

    public var inverse: AffineTransform3D {
        .init(matrix.inverse)
    }

    public func applying(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> AffineTransform3D {
        .init(
            (0..<4).map { row in
                (0..<4).map { column in
                    function(row, column, self[row, column])
                }
            }
        )
    }

    public static func linearInterpolation(_ from: AffineTransform3D, _ to: AffineTransform3D, factor: Double) -> AffineTransform3D {
        from.applying { row, column, value in
            value + (to[row, column] - value) * factor
        }
    }
}

extension AffineTransform3D {
    /// Creates a translation `AffineTransform3D` using the given x, y, and z offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    public static func translation(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform3D {
        var transform = identity
        transform[0, 3] = x
        transform[1, 3] = y
        transform[2, 3] = z
        return transform
    }

    /// Creates a translation `AffineTransform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    public static func translation(_ v: Vector3D) -> AffineTransform3D {
        translation(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a scaling `AffineTransform3D` using the given x, y, and z scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    public static func scaling(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform3D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        transform[2, 2] = z
        return transform
    }

    /// Creates a scaling `AffineTransform3D` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    public static func scaling(_ v: Vector3D) -> AffineTransform3D {
        scaling(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a `AffineTransform3D` for scaling all three axes uniformly
    ///
    /// - Parameter s: The scaling factor for all axes
    public static func scaling(_ s: Double) -> AffineTransform3D {
        scaling(x: s, y: s, z: s)
    }

    /// Creates a rotation `AffineTransform3D` using the given angles for rotation along the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    public static func rotation(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform3D {
        var transform = identity
        transform[0, 0] = cos(y) * cos(z)
        transform[0, 1] = sin(x) * sin(y) * cos(z) - cos(x) * sin(z)
        transform[0, 2] = cos(x) * sin(y) * cos(z) + sin(z) * sin(x)
        transform[1, 0] = cos(y) * sin(z)
        transform[1, 1] = sin(x) * sin(y) * sin(z) + cos(x) * cos(z)
        transform[1, 2] = cos(x) * sin(y) * sin(z) - sin(x) * cos(z)
        transform[2, 0] = -sin(y)
        transform[2, 1] = sin(x) * cos(y)
        transform[2, 2] = cos(x) * cos(y)
        return transform
    }

    /// Creates a rotation `AffineTransform3D` using a Rotation3D structure
    public static func rotation(_ r: Rotation3D) -> AffineTransform3D {
        return rotation(x: r.x, y: r.y, z: r.z)
    }

    /// Creates a shearing `AffineTransform3D` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform3D {
        precondition(axis != otherAxis, "Shearing requires two distinct axes")
        var t = AffineTransform3D.identity
        t[axis.index, otherAxis.index] = factor
        return t
    }

    /// Creates a shearing `AffineTransform3D` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform3D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, along: otherAxis, factor: factor)
    }
}

extension AffineTransform3D {
    /// Creates a new `AffineTransform3D` by concatenating a translation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    public func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform3D {
        concatenated(with: .translation(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform3D` by concatenating a translation with this transformation using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    public func translated(_ v: Vector3D) -> AffineTransform3D {
        concatenated(with: .translation(v))
    }

    /// Creates a new `AffineTransform3D` by concatenating a scaling transformation with this transformation using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    public func scaled(_ v: Vector3D) -> AffineTransform3D {
        concatenated(with: .scaling(v))
    }

    /// Creates a new `AffineTransform3D` by concatenating a scaling transformation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    public func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform3D {
        concatenated(with: .scaling(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform3D` by concatenating a rotation transformation with this transformation using the given Rotation3D.
    ///
    /// - Parameter r: A `Rotation3D` structure containing axis rotations
    public func rotated(_ r: Rotation3D) -> AffineTransform3D {
        concatenated(with: .rotation(r))
    }

    /// Creates a new `AffineTransform3D` by concatenating a rotation transformation with this transformation using the given angles for rotation.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    public func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform3D {
        concatenated(with: .rotation(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform3D` by concatenating a shearing transformation with this transformation.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    public func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform3D {
        concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
    }

    /// Creates a new `AffineTransform3D` by concatenating a shearing transformation with this transformation at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    public func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform3D {
        concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
    }
}

extension AffineTransform3D {
    /// Creates a new `AffineTransform3D` from a 2D affine transformation.
    ///
    /// - Parameter transform2d: The 2D affine transformation to convert.
    public init(_ transform2d: AffineTransform2D) {
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
    public func apply(to point: Vector3D) -> Vector3D {
        return Vector3D(matrixColumn: matrix * point.matrixColumn)
    }
}

extension AffineTransform3D: SCADValue {
    public var scadString: String {
        values.scadString
    }
}

fileprivate extension Axis3D {
    var index: Int {
        switch self {
        case .x: return 0
        case .y: return 1
        case .z: return 2
        }
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
