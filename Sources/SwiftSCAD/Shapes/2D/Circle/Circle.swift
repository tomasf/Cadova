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

    public var invocation: Invocation {
        .init(name: "circle", parameters: ["d": diameter])
    }

    public var boundary: Boundary<Vector2D> {
        .box([diameter, diameter])
        .translated([-diameter/2, -diameter/2])
    }
}
