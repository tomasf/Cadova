import Foundation

/// A value representing a geometric angle.
///
/// `Angle` encapsulates the concept of an angle without being tied to any specific unit.
/// You can easily create or inspect angles in degrees, radians, arcminutes, arcseconds,
/// or even full turns.
///
/// You can think of `Angle` as a semantic wrapper for angular values—mathematically unitless in storage,
/// but meaningfully constructed and interpreted in various units.
///
/// The most ergonomic way to create an angle is by using the suffix operator `°`, which converts a
/// `Double` into an `Angle` expressed in degrees:
///
/// ```swift
/// let rightAngle = 90°
/// let quarterTurn = Angle(turns: 0.25)
/// ```
public struct Angle: Sendable, Comparable, AdditiveArithmetic, Hashable, Codable {
    /// The angle expressed in degrees
    public let degrees: Double

    /// Create an angle from radians.
    ///
    /// Initializes an `Angle` instance using a radian value.
    ///
    /// - Parameter radians: The angle in radians.
    /// - Precondition: The radians value must be a finite number.
    public init(radians: Double) {
        precondition(radians.isFinite, "Angles can't be NaN or infinite")
        self.init(degrees: radians / .pi * 180.0)
    }

    /// Create an angle from degrees, and optionally, arcminutes and arcseconds.
    ///
    /// Initializes an `Angle` instance from degrees, with optional additional precision provided by arcminutes and arcseconds.
    ///
    /// - Parameters:
    ///   - degrees: The angle in degrees.
    ///   - arcmins: The angle in arcminutes, one sixtieth of a degree.
    ///   - arcsecs: The angle in arcseconds, one sixtieth of an arcminute.
    public init(degrees: Double, arcmins: Double = 0, arcsecs: Double = 0) {
        let totalDegrees = degrees + arcmins / 60.0 + arcsecs / 3600.0
        self.degrees = totalDegrees
    }

    /// Create an angle from a number of complete turns.
    ///
    /// Initializes an `Angle` instance where the angle is specified as a multiple of complete 360° rotations.
    ///
    /// - Parameter turns: The number of complete turns (360° rotations).
    /// - Precondition: The turns value must be a finite number.
    public init(turns: Double) {
        precondition(turns.isFinite, "Turns can't be NaN or infinite")
        self.init(radians: turns * 2.0 * .pi)
    }

    /// The angle expressed in radians
    public var radians: Double {
        degrees / 180.0 * .pi
    }

    /// The angle expressed in full turns (360°).
    public var turns: Double {
        radians / (2 * .pi)
    }

    /// Returns `true` if the angle is effectively zero, within floating-point precision.
    public var isZero: Bool {
        Swift.abs(radians) < .ulpOfOne
    }
}

public extension Angle {
    /// Create an angle from a radian value.
    ///
    /// - Parameter radians: The angle in radians.
    /// - Returns: An `Angle` instance representing the specified angle in radians.
    static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    /// Create an angle from a degree value.
    ///
    /// - Parameter degrees: The angle in degrees.
    /// - Returns: An `Angle` instance representing the specified angle in degrees.
    static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    /// Create an angle from a number of complete turns.
    ///
    /// - Parameter turns: The number of complete turns (360° rotations).
    /// - Returns: An `Angle` instance representing the specified angle in turns.
    static func turns(_ turns: Double) -> Angle {
        Angle(turns: turns)
    }

    /// Normalizes this angle to the range (-180°, 180°]
    var normalized: Angle {
        var r = radians
        while r <= -.pi { r += 2 * .pi }
        while r > .pi { r -= 2 * .pi }
        return Angle(radians: r)
    }
}

extension Angle: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "%g°", degrees)
    }
}

extension Angle {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(radians.rounded())
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.radians.roundedForHash == rhs.radians.roundedForHash
    }
}

