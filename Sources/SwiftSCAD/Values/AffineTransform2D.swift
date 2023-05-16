import Foundation
import simd

public struct AffineTransform2D: Equatable {
    var matrix: simd_double3x3

    init(_ matrix: simd_double3x3) {
        self.matrix = matrix
    }

    public init(_ values: [[Double]]) {
        precondition(
            values.count == 3 && values.allSatisfy { $0.count == 3},
            "AffineTransform2D requires 9 (3 x 3) elements"
        )
        self.matrix = .init(rows: values.map(SIMD3.init))
    }

    public subscript(_ row: Int, _ column: Int) -> Double {
        get {
            assert((0...2).contains(row), "Row index out of range")
            assert((0...2).contains(column), "Column index out of range")
            return matrix[row, column]
        }
        set {
            assert((0...2).contains(row), "Row index out of range")
            assert((0...2).contains(column), "Column index out of range")
            matrix[row, column] = newValue
        }
    }

    public static var identity: AffineTransform2D {
        AffineTransform2D(simd_double3x3(1.0))
    }

    public func concatenated(with other: AffineTransform2D) -> AffineTransform2D {
        AffineTransform2D(matrix * other.matrix)
    }
}

extension AffineTransform2D {
    public static func translation(x: Double = 0, y: Double = 0) -> AffineTransform2D {
        var transform = identity
        transform[0, 2] = x
        transform[1, 2] = y
        return transform
    }

    public static func translation(_ v: Vector2D) -> AffineTransform2D {
        translation(x: v.x, y: v.y)
    }

    public static func scaling(x: Double = 1, y: Double = 1) -> AffineTransform2D {
        var transform = identity
        transform[0, 0] = x
        transform[1, 1] = y
        return transform
    }

    public static func scaling(_ v: Vector2D) -> AffineTransform2D {
        scaling(x: v.x, y: v.y)
    }

    public static func rotation(_ angle: Angle) -> AffineTransform2D {
        var transform = identity
        transform[0, 0] = cos(angle)
        transform[0, 1] = -sin(angle)
        transform[1, 0] = sin(angle)
        transform[1, 1] = cos(angle)
        return transform
    }

    public static func shearing(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> AffineTransform2D {
        var t = AffineTransform2D.identity
        if axis == .x && otherAxis == .y {
            t[1, 0] = factor
        } else if axis == .y && otherAxis == .x {
            t[0, 1] = factor
        } else {
            preconditionFailure("Shearing requires two distinct axes")
        }
        return t
    }

    public static func shearing(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> AffineTransform2D {
        assert(angle > -90° && angle < 90°, "Angle needs to be between -90° and 90°")
        let factor = sin(angle) / sin(90° - angle)
        return shearing(axis, along: otherAxis, factor: factor)
    }
}

extension AffineTransform2D {
    public func translated(x: Double = 0, y: Double = 0) -> AffineTransform2D {
        concatenated(with: .translation(x: x, y: y))
    }

    public func translated(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .translation(v))
    }

    public func scaled(_ v: Vector2D) -> AffineTransform2D {
        concatenated(with: .scaling(v))
    }

    public func scaled(x: Double = 1, y: Double = 1) -> AffineTransform2D {
        concatenated(with: .scaling(x: x, y: y))
    }

    public func rotated(_ angle: Angle) -> AffineTransform2D {
        concatenated(with: .rotation(angle))
    }

    public func sheared(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> AffineTransform2D {
        concatenated(with: .shearing(axis, along: otherAxis, factor: factor))
    }

    public func sheared(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> AffineTransform2D {
        concatenated(with: .shearing(axis, along: otherAxis, angle: angle))
    }
}

extension AffineTransform2D {
    public func apply(to point: Vector2D) -> Vector2D {
        return Vector2D(simd3: point.simd3 * matrix)
    }
}

extension AffineTransform2D {
    public init(_ transform3d: AffineTransform) {
        self = .identity

        self[0, 0] = transform3d[0, 0]
        self[0, 1] = transform3d[0, 1]
        self[1, 0] = transform3d[1, 0]
        self[1, 1] = transform3d[1, 1]

        self[0, 2] = transform3d[0, 3]
        self[1, 2] = transform3d[1, 3]
    }
}

