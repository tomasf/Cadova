import Foundation

/// Calculate the sine of an angle.
///
/// - Parameter angle: The angle for which to calculate the sine.
/// - Returns: The sine of the given angle.
///
public func sin(_ angle: Angle) -> Double {
    // Sine function where multiples of 90 degrees come out exact.
    // Borrowed from Manifold: https://github.com/elalish/manifold/blob/master/include/manifold/common.h

    guard angle >= 0° else { return -sin(-angle) }

    var quotient: Int32 = 0
    let remainder = remquo(angle.degrees, 90, &quotient) / 180 * .pi

    return switch quotient % 4 {
    case 0: sin(remainder)
    case 1: cos(remainder)
    case 2: -sin(remainder)
    case 3: -cos(remainder)
    default: 0
    }
}

/// Calculate the cosine of an angle.
///
/// - Parameter angle: The angle for which to calculate the cosine.
/// - Returns: The cosine of the given angle.
public func cos(_ angle: Angle) -> Double {
    sin(angle + 90°)
}

/// Calculate the tangent of an angle.
///
/// - Parameter angle: The angle for which to calculate the tangent.
/// - Returns: The tangent of the given angle.
public func tan(_ angle: Angle) -> Double {
    sin(angle) / cos(angle)
}

/// Calculate the secant of an angle (1 / cosine).
///
/// - Parameter angle: The angle for which to calculate the secant.
/// - Returns: The secant of the given angle.
public func sec(_ angle: Angle) -> Double {
    1 / cos(angle)
}

/// Calculate the cosecant of an angle (1 / sine).
///
/// - Parameter angle: The angle for which to calculate the cosecant.
/// - Returns: The cosecant of the given angle.
public func csc(_ angle: Angle) -> Double {
    1 / sin(angle)
}

/// Calculate the cotangent of an angle (1 / tangent).
///
/// - Parameter angle: The angle for which to calculate the cotangent.
/// - Returns: The cotangent of the given angle.
public func cot(_ angle: Angle) -> Double {
    1 / tan(angle)
}

// - MARK: Inverse

/// Calculate the arcsine of a value.
///
/// - Parameter value: The value for which to calculate the arcsine.
/// - Returns: The angle whose sine is the given value.
public func asin(_ value: Double) -> Angle {
    Angle(radians: asin(value))
}

/// Calculate the arccosine of a value.
///
/// - Parameter value: The value for which to calculate the arccosine.
/// - Returns: The angle whose cosine is the given value.
public func acos(_ value: Double) -> Angle {
    Angle(radians: acos(value))
}

/// Calculate the arctangent of a value.
///
/// - Parameter value: The value for which to calculate the arctangent.
/// - Returns: The angle whose tangent is the given value.
public func atan(_ value: Double) -> Angle {
    Angle(radians: atan(value))
}

/// Calculate the arctangent of two values, considering their signs to determine the correct quadrant.
///
/// The `atan2` function computes the angle whose tangent is `y/x`, using the signs of both arguments to place the result in the correct quadrant of the unit circle. This is useful for determining the direction of a point `(x, y)` from the origin.
///
/// - Parameters:
///   - y: The Y-coordinate.
///   - x: The X-coordinate.
/// - Returns: The angle, in radians, between the positive X-axis and the point `(x, y)`.
///
public func atan2(_ y: Double, _ x: Double) -> Angle {
    Angle(radians: atan2(y, x))
}

/// Calculate the arcsecant (inverse of secant) of a value.
///
/// - Parameter value: The value for which to calculate the arcsecant.
/// - Returns: The angle whose secant is the given value.
public func asec(_ value: Double) -> Angle {
    Angle(radians: acos(1 / value))
}

/// Calculate the arccosecant (inverse of cosecant) of a value.
///
/// - Parameter value: The value for which to calculate the arccosecant.
/// - Returns: The angle whose cosecant is the given value.
public func acsc(_ value: Double) -> Angle {
    Angle(radians: asin(1 / value))
}

/// Calculate the arccotangent (inverse of cotangent) of a value.
///
/// - Parameter value: The value for which to calculate the arccotangent.
/// - Returns: The angle whose cotangent is the given value.
public func acot(_ value: Double) -> Angle {
    Angle(radians: atan(1 / value))
}
