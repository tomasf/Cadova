import Foundation

public extension Double {
    /// Convenience postfix operator for creating an angle from a value in degrees
    ///
    /// ## Example
    /// ```swift
    /// let angle = 45°
    /// ```
    static postfix func °(_ a: Double) -> Angle {
        Angle(degrees: a)
    }
}

public extension Angle {
    static let zero = 0°

    static prefix func -(_ a: Angle) -> Angle {
        Angle(degrees: -a.degrees)
    }

    static func +(_ a: Angle, _ b: Angle) -> Angle {
        Angle(degrees: a.degrees + b.degrees)
    }

    static func -(_ a: Angle, _ b: Angle) -> Angle {
        Angle(degrees: a.degrees - b.degrees)
    }
}

public extension Angle {
    static func *(_ a: Angle, _ b: Double) -> Angle {
        Angle(degrees: a.degrees * b)
    }

    static func *(_ a: Double, _ b: Angle) -> Angle {
        Angle(degrees: a * b.degrees)
    }

    static func /(_ a: Angle, _ b: Double) -> Angle {
        Angle(degrees: a.degrees / b)
    }

    static func /(_ a: Angle, _ b: Angle) -> Double {
        a.degrees / b.degrees
    }
}

public extension Angle {
    static func <(_ a: Angle, _ b: Angle) -> Bool {
        a.degrees < b.degrees
    }
}

// To support stride, we'd ideally conform Angle to Strideable. However, that requires that Angle conforms
// to Numeric, which requires multiplication. Multiplying two angles is not meaningful, so we can't do that.
// Hence these manual overloads of stride().

public func stride(from start: Angle, through end: Angle, by stride: Angle) -> [Angle] {
    Swift.stride(from: start.degrees, through: end.degrees, by: stride.degrees)
        .map { $0° }
}

public func stride(from start: Angle, to end: Angle, by stride: Angle) -> [Angle] {
    Swift.stride(from: start.degrees, to: end.degrees, by: stride.degrees)
        .map { $0° }
}

/// Calculate the absolute value of an angle.
///
/// This function returns the absolute value of an angle, ensuring the angle's magnitude is positive. It is
/// particularly useful in contexts where the direction of the angle (clockwise or counterclockwise) is irrelevant.
///
/// - Parameter angle: The angle for which to compute the absolute value.
/// - Returns: An `Angle` instance representing the absolute value of the specified angle.
public func abs(_ angle: Angle) -> Angle {
    Angle(degrees: Swift.abs(angle.degrees))
}
