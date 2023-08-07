import Foundation
import simd

/// An `AffineTransform` represents a 3D affine transformation using a 4x4 matrix.
public struct AffineTransform: Equatable {
    var matrix: simd_double4x4

    private init(_ matrix: simd_double4x4) {
        self.matrix = matrix
    }

    /// Creates an `AffineTransform` with the specified 4x4 matrix.
    ///
    /// - Parameter values: A 2D array of `Double` with 4x4 elements in row-major order.
    public init(_ values: [[Double]]) {
        precondition(
            values.count == 4 && values.allSatisfy { $0.count == 4},
            "AffineTransform requires 16 (4 x 4) elements"
        )
        self.init(simd_double4x4(rows: values.map(SIMD4.init)))
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
            return matrix[row, column]
        }
        set {
            assert((0...3).contains(row), "Row index out of range")
            assert((0...3).contains(column), "Column index out of range")
            matrix[row, column] = newValue
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

    /// The identity `AffineTransform`, representing no transformation.
    public static var identity: AffineTransform {
        AffineTransform(simd_double4x4(1))
    }

    /// Concatenates this `AffineTransform` with another, creating a new combined transformation.
    ///
    /// - Parameter other: The `AffineTransform` to concatenate with.
    public func concatenated(with other: AffineTransform) -> AffineTransform {
        AffineTransform(matrix * other.matrix)
    }
}

extension AffineTransform {
    /// Creates a translation `AffineTransform` using the given x, y, and z offsets.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    public static func translation(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform {
        var transform = identity
        transform[0, 3] = x
        transform[1, 3] = y
        transform[2, 3] = z
        return transform
    }

    /// Creates a translation `AffineTransform` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    public static func translation(_ v: Vector3D) -> AffineTransform {
        translation(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a scaling `AffineTransform` using the given x, y, and z scaling factors.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    public static func scaling(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        transform[2, 2] = z
        return transform
    }

    /// Creates a scaling `AffineTransform` using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    public static func scaling(_ v: Vector3D) -> AffineTransform {
        scaling(x: v.x, y: v.y, z: v.z)
    }

    /// Creates a rotation `AffineTransform` using the given angles for rotation along the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    public static func rotation(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform {
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

    /// Creates a rotation `AffineTransform` using the given array of angles for rotation along the x, y, and z axes.
    ///
    /// - Parameter a: An array containing the rotation angles for x, y, and z axes, respectively.
    public static func rotation(_ a: [Angle]) -> AffineTransform {
        assert(a.count == 3, "Rotate expects three angles")
        return rotation(x: a[0], y: a[1], z: a[2])
    }

    /// Creates a shearing `AffineTransform` that skews along one axis with respect to another axis.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear along.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform {
        precondition(axis != otherAxis, "Shearing requires two distinct axes")
        var t = AffineTransform.identity
        t[axis.index, otherAxis.index] = factor
        return t
    }

    /// Creates a shearing `AffineTransform` that skews along one axis with respect to another axis at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear along.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    public static func shearing(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, along: otherAxis, factor: factor)
    }
}

extension AffineTransform {
    /// Creates a new `AffineTransform` by concatenating a translation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The x-axis translation offset.
    ///   - y: The y-axis translation offset.
    ///   - z: The z-axis translation offset.
    public func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> AffineTransform {
        concatenated(with: .translation(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform` by concatenating a translation with this transformation using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the translation along each axis.
    public func translated(_ v: Vector3D) -> AffineTransform {
        concatenated(with: .translation(v))
    }

    /// Creates a new `AffineTransform` by concatenating a scaling transformation with this transformation using the given 3D vector.
    ///
    /// - Parameter v: The 3D vector representing the scaling along each axis.
    public func scaled(_ v: Vector3D) -> AffineTransform {
        concatenated(with: .scaling(v))
    }

    /// Creates a new `AffineTransform` by concatenating a scaling transformation with this transformation.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    public func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> AffineTransform {
        concatenated(with: .scaling(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform` by concatenating a rotation transformation with this transformation using the given array of angles.
    ///
    /// - Parameter a: An array containing the rotation angles for x, y, and z axes, respectively.
    public func rotated(_ a: [Angle]) -> AffineTransform {
        concatenated(with: .rotation(a))
    }

    /// Creates a new `AffineTransform` by concatenating a rotation transformation with this transformation using the given angles for rotation.
    ///
    /// - Parameters:
    ///   - x: The rotation angle around the x-axis.
    ///   - y: The rotation angle around the y-axis.
    ///   - z: The rotation angle around the z-axis.
    public func rotated(x: Angle = 0°, y: Angle = 0°, z: Angle = 0°) -> AffineTransform {
        concatenated(with: .rotation(x: x, y: y, z: z))
    }

    /// Creates a new `AffineTransform` by concatenating a shearing transformation with this transformation.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear along.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - factor: The shearing factor.
    public func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> AffineTransform {
        concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
    }

    /// Creates a new `AffineTransform` by concatenating a shearing transformation with this transformation at the given angle.
    ///
    /// - Parameters:
    ///   - axis: The axis to shear along.
    ///   - otherAxis: The axis to shear with respect to.
    ///   - angle: The angle of shearing.
    public func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> AffineTransform {
        concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
    }
}

extension AffineTransform {
    /// Creates a new `AffineTransform` from a 2D affine transformation.
    ///
    /// - Parameter transform2d: The 2D affine transformation to convert.
    public init(_ transform2d: AffineTransform2D) {
        var transform = AffineTransform.identity
        
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
        return Vector3D(simd4: point.simd4 * matrix)
    }
}

extension AffineTransform: SCADValue {
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
