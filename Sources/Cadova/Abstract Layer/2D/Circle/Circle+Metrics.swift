import Foundation

public extension Circle {
    /// Calculates the corresponding coordinate on the circle (X or Y) given the known coordinate.
    ///
    /// Given a known coordinate (either X or Y), this function returns the positive corresponding coordinate.
    ///
    /// - Parameter knownCoordinate: The known coordinate (either X or Y).
    /// - Returns: The positive corresponding coordinate (Y if X is provided, X if Y is provided).
    /// - Precondition: The known coordinate must be within the circle's radius.
    ///
    func correspondingCoordinate(for knownCoordinate: Double) -> Double {
        precondition(Swift.abs(knownCoordinate) <= radius, "The coordinate must be within the circle's radius.")
        return sqrt(radius * radius - knownCoordinate * knownCoordinate)
    }

    /// Calculates the chord length for a given sagitta in the circle.
    ///
    /// The chord length is the straight-line distance between two points on the circle's circumference
    /// corresponding to the provided sagitta (the height of the arc).
    ///
    /// - Parameter sagitta: The sagitta (height of the arc) for which to calculate the chord length.
    ///   Must be greater than or equal to 0, and less than or equal to the radius of the circle.
    /// - Returns: The chord length corresponding to the provided sagitta.
    /// - Precondition: `sagitta` must be greater than or equal to 0.
    /// - Precondition: `sagitta` must be less than or equal to the radius of the circle.
    ///
    func chordLength(atSagitta sagitta: Double) -> Double {
        precondition(sagitta >= 0, "Sagitta must be greater than or equal to 0.")
        precondition(sagitta <= radius, "Sagitta must be less than or equal to the radius.")

        return 2.0 * sqrt((radius * radius) - ((radius - sagitta) * (radius - sagitta)))
    }

    /// Calculates the sagitta (height of the arc) given the chord length in the circle.
    ///
    /// The sagitta is the distance from the center of the chord to the arc of the circle.
    ///
    /// - Parameter chordLength: The length of the chord. Must be less than or equal to the diameter of the circle.
    /// - Returns: The sagitta corresponding to the provided chord length.
    /// - Precondition: `chordLength` must be greater than or equal to 0.
    /// - Precondition: `chordLength` must be less than or equal to the diameter of the circle.
    ///
    func sagitta(atChordLength chordLength: Double) -> Double {
        precondition(chordLength >= 0, "Chord length must be greater than or equal to 0.")
        precondition(chordLength <= diameter, "Chord length must be less than or equal to the diameter of the circle.")

        return radius - ((radius * radius) - ((chordLength / 2.0) * (chordLength / 2.0))).squareRoot()
    }

    var circumference: Double {
        diameter * .pi
    }
}

extension Circle: Area, Perimeter {
    public var area: Double {
        radius * radius * .pi
    }

    public var perimeter: Double { circumference }
}
