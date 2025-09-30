import Foundation

public extension Vector3D {
    /// Returns a new vector by adding a scalar to each component of the vector.
    ///
    /// - Parameters:
    ///   - v: The vector to add to.
    ///   - s: The scalar to add.
    /// - Returns: A new vector with each component increased by `s`.
    static func +(_ v: Vector3D, _ s: Double) -> Vector3D {
        Vector3D(
            x: v.x + s,
            y: v.y + s,
            z: v.z + s
        )
    }

    /// Returns a new vector by adding a scalar to each component of the vector.
    ///
    /// - Parameters:
    ///   - s: The scalar to add.
    ///   - v: The vector to add to.
    /// - Returns: A new vector with each component increased by `s`.
    static func +(_ s: Double, _ v: Vector3D) -> Vector3D {
        Vector3D(
            x: v.x + s,
            y: v.y + s,
            z: v.z + s
        )
    }

    /// Returns a new vector by subtracting a scalar from each component of the vector.
    ///
    /// - Parameters:
    ///   - v: The vector to subtract from.
    ///   - s: The scalar to subtract.
    /// - Returns: A new vector with each component decreased by `s`.
    static func -(_ v: Vector3D, _ s: Double) -> Vector3D {
        Vector3D(
            x: v.x - s,
            y: v.y - s,
            z: v.z - s
        )
    }
    
    /// Returns a new vector by multiplying each component of the vector by a scalar.
    ///
    /// - Parameters:
    ///   - v: The vector to multiply.
    ///   - d: The scalar to multiply by.
    /// - Returns: A new vector with each component multiplied by `d`.
    static func *(_ v: Vector3D, _ d: Double) -> Vector3D {
        Vector3D(
            x: v.x * d,
            y: v.y * d,
            z: v.z * d
        )
    }
    
    /// Returns a new vector by multiplying each component of the vector by a scalar (scalar first).
    ///
    /// - Parameters:
    ///   - d: The scalar to multiply by.
    ///   - v: The vector to multiply.
    /// - Returns: A new vector with each component multiplied by `d`.
    static func *(_ d: Double, _ v: Vector3D) -> Vector3D {
        Vector3D(
            x: v.x * d,
            y: v.y * d,
            z: v.z * d
        )
    }
    
    /// Returns a new vector by dividing each component of the vector by a scalar.
    ///
    /// - Parameters:
    ///   - v: The vector to divide.
    ///   - d: The scalar to divide by.
    /// - Returns: A new vector with each component divided by `d`.
    static func /(_ v: Vector3D, _ d: Double) -> Vector3D {
        Vector3D(
            x: v.x / d,
            y: v.y / d,
            z: v.z / d
        )
    }
}

public extension Vector3D {
    /// Returns the component-wise sum of two vectors.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector with each component equal to the sum of the corresponding components of `v1` and `v2`.
    static func +(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x + v2.x,
            y: v1.y + v2.y,
            z: v1.z + v2.z
        )
    }
    
    /// Returns the component-wise difference of two vectors.
    ///
    /// - Parameters:
    ///   - v1: The vector to subtract from.
    ///   - v2: The vector to subtract.
    /// - Returns: A new vector with each component equal to the difference of the corresponding components of `v1` and `v2`.
    static func -(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x - v2.x,
            y: v1.y - v2.y,
            z: v1.z - v2.z
        )
    }
    
    /// Returns the component-wise product of two vectors.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector with each component equal to the product of the corresponding components of `v1` and `v2`.
    static func *(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x * v2.x,
            y: v1.y * v2.y,
            z: v1.z * v2.z
        )
    }
    
    /// Returns the component-wise quotient of two vectors.
    ///
    /// - Parameters:
    ///   - v1: The numerator vector.
    ///   - v2: The denominator vector.
    /// - Returns: A new vector with each component equal to the quotient of the corresponding components of `v1` and `v2`.
    static func /(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.x / v2.x,
            y: v1.y / v2.y,
            z: v1.z / v2.z
        )
    }
}

public extension Vector3D {
    /// Returns the negation of a vector.
    ///
    /// - Parameter v: The vector to negate.
    /// - Returns: A new vector with each component negated.
    static prefix func -(_ v: Vector3D) -> Vector3D {
        Vector3D(
            x: -v.x,
            y: -v.y,
            z: -v.z
        )
    }
    
    /// Returns the cross product of two 3D vectors.
    ///
    /// The cross product of two vectors results in a third vector that is perpendicular
    /// to the plane formed by the input vectors, following the right-hand rule.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A new vector perpendicular to both `v1` and `v2`.
    static func ×(_ v1: Vector3D, _ v2: Vector3D) -> Vector3D {
        Vector3D(
            x: v1.y * v2.z - v1.z * v2.y,
            y: v1.z * v2.x - v1.x * v2.z,
            z: v1.x * v2.y - v1.y * v2.x
        )
    }
    
    /// Returns the dot product of two 3D vectors.
    ///
    /// The dot product is the sum of the products of corresponding components,
    /// and is a measure of how aligned the two vectors are.
    ///
    /// - Parameters:
    ///   - v1: The first vector.
    ///   - v2: The second vector.
    /// - Returns: A scalar value representing the dot product of `v1` and `v2`.
    static func ⋅(_ v1: Vector3D, _ v2: Vector3D) -> Double {
        v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }
}

public extension Vector3D {
    /// Adds a scalar to each component of the vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar to add.
    static func += (lhs: inout Vector3D, rhs: Double) { lhs = lhs + rhs }
    
    /// Subtracts a scalar from each component of the vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar to subtract.
    static func -= (lhs: inout Vector3D, rhs: Double) { lhs = lhs - rhs }

    /// Multiplies each component of the vector by a scalar in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar to multiply by.
    static func *= (lhs: inout Vector3D, rhs: Double) { lhs = lhs * rhs }

    /// Divides each component of the vector by a scalar in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The scalar to divide by.
    static func /= (lhs: inout Vector3D, rhs: Double) { lhs = lhs / rhs }
    
    /// Adds the corresponding components of another vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to add.
    static func += (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs + rhs }

    /// Subtracts the corresponding components of another vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to subtract.
    static func -= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs - rhs }

    /// Multiplies the corresponding components of another vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to multiply by.
    static func *= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs * rhs }

    /// Divides the corresponding components of another vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to divide by.
    static func /= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs / rhs }
    
    /// Performs the cross product with another vector in place.
    ///
    /// - Parameters:
    ///   - lhs: The vector to modify.
    ///   - rhs: The vector to cross with.
    static func ×= (lhs: inout Vector3D, rhs: Vector3D) { lhs = lhs × rhs }
}
