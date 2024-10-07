import Foundation

/// A value representing a geometric angle
public struct Angle: Sendable {
    /// The angle expressed in radians
    public let radians: Double

    /// Create an angle from radians.
    ///
    /// Initializes an `Angle` instance using a radian value.
    ///
    /// - Parameter radians: The angle in radians.
    /// - Precondition: The radians value must be a finite number.
    public init(radians: Double) {
        precondition(radians.isFinite, "Angles can't be NaN or infinite")
        self.radians = radians
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
        self.init(radians: totalDegrees * .pi / 180.0)
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

    /// The angle expressed in degrees
    public var degrees: Double {
        radians / (.pi / 180.0)
    }

    /// The angle expressed in complete turns
    public var turns: Double {
        radians / (2 * .pi)
    }
}

public extension Angle {
    /// Create an angle from a radian value.
    ///
    /// Provides a static method to create an `Angle` from radians, facilitating readability and use where the context explicitly calls for radians.
    ///
    /// - Parameter radians: The angle in radians.
    /// - Returns: An `Angle` instance representing the specified angle in radians.
    static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    /// Create an angle from a degree value.
    ///
    /// Provides a static method to create an `Angle` from degrees, supporting use cases or contexts where angles are commonly expressed in degrees.
    ///
    /// - Parameter degrees: The angle in degrees.
    /// - Returns: An `Angle` instance representing the specified angle in degrees.
    static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    /// Create an angle from a number of complete turns.
    ///
    /// Provides a static method to create an `Angle` from turns, making it easy to express angles as multiples of 360° rotations.
    ///
    /// - Parameter turns: The number of complete turns (360° rotations).
    /// - Returns: An `Angle` instance representing the specified angle in turns.
    static func turns(_ turns: Double) -> Angle {
        Angle(turns: turns)
    }
}

extension Angle: SCADValue {
    public var scadString: String {
        degrees.scadString
    }
}

extension Angle: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "%g°", degrees)
    }
}

