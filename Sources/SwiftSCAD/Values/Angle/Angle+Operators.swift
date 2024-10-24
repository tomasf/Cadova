import Foundation

postfix operator °

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

extension Angle: AdditiveArithmetic {}

public extension Angle {
    static let zero = 0°

    static prefix func -(_ a: Angle) -> Angle {
        Angle(radians: -a.radians)
    }

    static func +(_ a: Angle, _ b: Angle) -> Angle {
        Angle(radians: a.radians + b.radians)
    }

    static func -(_ a: Angle, _ b: Angle) -> Angle {
        Angle(radians: a.radians - b.radians)
    }
}

public extension Angle {
    static func *(_ a: Angle, _ b: Double) -> Angle {
        Angle(radians: a.radians * b)
    }

    static func *(_ a: Double, _ b: Angle) -> Angle {
        Angle(radians: a * b.radians)
    }

    static func /(_ a: Angle, _ b: Double) -> Angle {
        Angle(radians: a.radians / b)
    }

    static func /(_ a: Angle, _ b: Angle) -> Double {
        a.radians / b.radians
    }
}

extension Angle: Comparable {}
public extension Angle {
    static func <(_ a: Angle, _ b: Angle) -> Bool {
        a.radians < b.radians
    }

    static func ==(_ a: Angle, _ b: Angle) -> Bool {
        a.radians == b.radians
    }
}

// To support stride, we'd ideally conform Angle to Strideable. However, that requires that Angle conforms
// to Numeric, which requires multiplication. Multiplying two angles is not meaningful, so we can't do that.
// Hence these manual overloads of stride().

public func stride(from start: Angle, through end: Angle, by stride: Angle) -> [Angle] {
    Swift.stride(from: start.radians, through: end.radians, by: stride.radians)
        .map(Angle.init(radians:))
}

public func stride(from start: Angle, to end: Angle, by stride: Angle) -> [Angle] {
    Swift.stride(from: start.radians, to: end.radians, by: stride.radians)
        .map(Angle.init(radians:))
}

/// Calculate the absolute value of an angle.
///
/// This function returns the absolute value of an angle, ensuring the angle's magnitude is positive. It is particularly useful in contexts where the direction of the angle (clockwise or counterclockwise) is irrelevant.
///
/// - Parameter angle: The angle for which to compute the absolute value.
/// - Returns: An `Angle` instance representing the absolute value of the specified angle.
public func abs(_ angle: Angle) -> Angle {
    Angle(radians: abs(angle.radians))
}
