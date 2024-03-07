import Foundation

/// A value representing a geometric angle
public struct Angle {
    /// The angle expressed in radians
    public let radians: Double

    /// Create an angle from radians
    public init(radians: Double) {
        precondition(radians.isFinite, "Angles can't be NaN or infinite")
        self.radians = radians
    }

    /// Create an angle from degrees, and optionally, arcminutes and arcseconds
    public init(degrees: Double, arcmins: Double = 0, arcsecs: Double = 0) {
        let totalDegrees = degrees + arcmins / 60.0 + arcsecs / 3600.0
        self.init(radians: totalDegrees * .pi / 180.0)
    }

    /// The angle expressed in degrees
    public var degrees: Double {
        radians / (.pi / 180.0)
    }
}

public extension Angle {
    static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }
}

extension Angle: SCADValue {
    public var scadString: String {
        degrees.scadString
    }
}

extension Angle: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(degrees)°"
    }
}

public func abs(_ angle: Angle) -> Angle {
    Angle(radians: abs(angle.radians))
}
