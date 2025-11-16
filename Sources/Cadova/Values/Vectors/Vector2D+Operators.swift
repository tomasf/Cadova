import Foundation

public extension Vector2D {
    /// Adds a scalar to both components of the vector.
    ///
    /// - Parameters:
    ///   - v: The input vector.
    ///   - s: The scalar value to add.
    /// - Returns: A new vector with each component increased by the scalar.
    static func +(_ v: Vector2D, _ s: Double) -> Vector2D {
        Vector2D(
            x: v.x + s,
            y: v.y + s
        )
    }

    /// Adds a scalar to both components of the vector.
    ///
    /// - Parameters:
    ///   - s: The scalar value to add.
    ///   - v: The input vector.
    /// - Returns: A new vector with each component increased by the scalar.
    static func +(_ s: Double, _ v: Vector2D) -> Vector2D {
        Vector2D(
            x: v.x + s,
            y: v.y + s
        )
    }

    /// Subtracts a scalar from both components of the vector.
    ///
    /// - Parameters:
    ///   - v: The input vector.
    ///   - s: The scalar value to subtract.
    /// - Returns: A new vector with each component decreased by the scalar.
    static func -(_ v: Vector2D, _ s: Double) -> Vector2D {
        Vector2D(
            x: v.x - s,
            y: v.y - s
        )
    }

    /// Multiplies both components of the vector by a scalar.
    ///
    /// This scales the vector uniformly along both axes.
    ///
    /// - Parameters:
    ///   - v: The input vector.
    ///   - d: The scalar value to multiply with.
    /// - Returns: A new vector with each component multiplied by the scalar.
    static func *(_ v: Vector2D, _ d: Double) -> Vector2D {
        Vector2D(
            x: v.x * d,
            y: v.y * d
        )
    }

    /// Multiplies both components of the vector by a scalar.
    ///
    /// This scales the vector uniformly along both axes.
    ///
    /// - Parameters:
    ///   - d: The scalar value to multiply with.
    ///   - v: The input vector.
    /// - Returns: A new vector with each component multiplied by the scalar.
    static func *(_ d: Double, _ v: Vector2D) -> Vector2D {
        Vector2D(
            x: v.x * d,
            y: v.y * d
        )
    }

    /// Divides both components of the vector by a scalar.
    ///
    /// - Parameters:
    ///   - v: The input vector.
    ///   - d: The scalar value to divide by.
    /// - Returns: A new vector with each component divided by the scalar.
    static func /(_ v: Vector2D, _ d: Double) -> Vector2D {
        Vector2D(
            x: v.x / d,
            y: v.y / d
        )
    }
}

public extension Vector2D {
    /// Adds two vectors component-wise.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector representing the sum.
    static func +(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x + v2.x,
            y: v1.y + v2.y
        )
    }

    /// Subtracts the second vector from the first component-wise.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector representing the difference.
    static func -(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x - v2.x,
            y: v1.y - v2.y
        )
    }

    /// Multiplies two vectors component-wise.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector representing the product.
    static func *(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x * v2.x,
            y: v1.y * v2.y
        )
    }

    /// Divides the first vector by the second component-wise.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector representing the quotient.
    static func /(_ v1: Vector2D, _ v2: Vector2D) -> Vector2D {
        Vector2D(
            x: v1.x / v2.x,
            y: v1.y / v2.y
        )
    }
}

public extension Vector2D {
    /// Negates both components of the vector.
    ///
    /// - Parameter v: The input vector.
    /// - Returns: A new vector with both components negated.
    static prefix func -(_ v: Vector2D) -> Vector2D {
        v * -1
    }

    /// Computes the 2D cross product of two vectors.
    ///
    /// The result is a scalar representing the magnitude of the vector that would result
    /// from the 3D cross product if the 2D vectors were interpreted as lying in the XY plane.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A scalar representing the z-component of the cross product.
    static func ×(v1: Vector2D, v2: Vector2D) -> Double {
        v1.x * v2.y - v1.y * v2.x
    }

    /// Computes the dot product of two vectors.
    ///
    /// The dot product is a measure of how aligned the two vectors are.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A scalar value representing the dot product.
    static func ⋅(v1: Vector2D, v2: Vector2D) -> Double {
        v1.x * v2.x + v1.y * v2.y
    }
}

public extension Vector2D {
    /// Adds a scalar to both components of the vector in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar value to add.
    static func += (lhs: inout Vector2D, rhs: Double) { lhs = lhs + rhs }

    /// Subtracts a scalar from both components of the vector in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar value to subtract.
    static func -= (lhs: inout Vector2D, rhs: Double) { lhs = lhs - rhs }

    /// Multiplies both components of the vector by a scalar in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar value to multiply with.
    static func *= (lhs: inout Vector2D, rhs: Double) { lhs = lhs * rhs }

    /// Divides both components of the vector by a scalar in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar value to divide by.
    static func /= (lhs: inout Vector2D, rhs: Double) { lhs = lhs / rhs }

    /// Adds another vector to this one in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to add.
    static func += (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs + rhs }

    /// Subtracts another vector from this one in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to subtract.
    static func -= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs - rhs }

    /// Multiplies this vector by another vector component-wise in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to multiply with.
    static func *= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs * rhs }

    /// Divides this vector by another vector component-wise in-place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to divide by.
    static func /= (lhs: inout Vector2D, rhs: Vector2D) { lhs = lhs / rhs }
}
