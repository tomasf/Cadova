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

    /// Creates a new `Circle` instance with the specified diameter.
    ///
    /// - Parameter diameter: The diameter of the circle.
    public init(diameter: Double) {
        self.diameter = diameter
    }

    /// Creates a new `Circle` instance with the specified radius.
    ///
    /// - Parameter radius: The radius of the circle.
    public init(radius: Double) {
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
        diameter = sagitta + (pow(chordLength, 2) / (4 * sagitta))
    }

    public var invocation: Invocation {
        .init(name: "circle", parameters: ["d": diameter])
    }

    public func boundary(in environment: Environment) -> Bounds {
        .circle(radius: diameter / 2, facets: environment.facets)
    }
}

extension Circle: Area2D {
    public var area: Double { (diameter / 2) * (diameter / 2) * .pi }
}
