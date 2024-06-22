import Foundation

/// A `Circle` represents a two-dimensional geometric shape that can be defined by its diameter or radius.
///
/// # Example
/// ```swift
/// let circleWithDiameter = Circle(diameter: 10)
/// let circleWithRadius = Circle(radius: 5)
/// ```
public struct Circle: LeafGeometry2D {
    /// The diameter of the circle.
    public let diameter: Double

    public var radius: Double { diameter / 2 }

    /// Creates a new `Circle` instance with the specified diameter.
    ///
    /// - Parameter diameter: The diameter of the circle.
    public init(diameter: Double) {
        precondition(diameter > 0, "Diameter must be greater than 0.")
        self.diameter = diameter
    }

    /// Creates a new `Circle` instance with the specified radius.
    ///
    /// - Parameter radius: The radius of the circle.
    public init(radius: Double) {
        precondition(radius > 0, "Radius must be greater than 0.")
        self.diameter = radius * 2
    }

    /// Creates a new `Circle` instance with the specified chord length and sagitta.
    ///
    /// This initializer calculates the diameter of the circle based on the geometric
    /// relationship between the chord length and the sagitta—the vertical distance from
    /// the midpoint of the chord to the arc of the circle.
    ///
    /// - Parameters:
    ///   - chordLength: The length of the chord of the circle.
    ///   - sagitta: The height from the midpoint of the chord to the highest point of the arc.
    public init(chordLength: Double, sagitta: Double) {
        precondition(chordLength > 0, "Chord length must be greater than 0.")
        precondition(sagitta > 0, "Sagitta must be greater than 0.")
        precondition(sagitta <= chordLength / 2, "Sagitta must be less than or equal to half of the chord length.")
        
        diameter = sagitta + (pow(chordLength, 2) / (4 * sagitta))
    }

    public var invocation: Invocation {
        .init(name: "circle", parameters: ["d": diameter])
    }

    public func boundary(in environment: Environment) -> Bounds {
        .circle(radius: diameter / 2, facets: environment.facets)
    }
}

public extension Circle {
    func chordLength(atSagitta sagitta: Double) -> Double {
        precondition(sagitta >= 0, "Sagitta must be greater than or equal to 0.")
        precondition(sagitta <= radius, "Sagitta must be less than or equal to the radius.")
        
        return 2.0 * sqrt((radius * radius) - ((radius - sagitta) * (radius - sagitta)))
    }
}

extension Circle: Area2D {
    public var area: Double { (diameter / 2) * (diameter / 2) * .pi }
}
