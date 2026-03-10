import Foundation
import Manifold3D

/// A `Circle` represents a two-dimensional geometric shape that can be defined by its diameter or radius.
///
/// # Example
/// ```swift
/// let circleWithDiameter = Circle(diameter: 10)
/// let circleWithRadius = Circle(radius: 5)
/// ```
public struct Circle: Hashable, Sendable, Codable {
    /// The radius of the circle.
    public let radius: Double

    /// The diameter of the circle (twice the radius).
    public var diameter: Double { radius * 2 }

    /// Creates a new `Circle` instance with the specified diameter.
    ///
    /// - Parameter diameter: The diameter of the circle. A value of zero represents a degenerate point circle.
    public init(diameter: Double) {
        precondition(diameter.isFinite, "Diameter must be finite.")
        precondition(diameter >= 0, "Diameter must not be negative.")
        self.radius = diameter / 2
    }

    /// Creates a new `Circle` instance with the specified radius.
    ///
    /// - Parameter radius: The radius of the circle. A value of zero represents a degenerate point circle.
    public init(radius: Double) {
        precondition(radius.isFinite, "Radius must be finite.")
        precondition(radius >= 0, "Radius must not be negative.")
        self.radius = radius
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
        precondition(chordLength.isFinite, "Chord length must be finite.")
        precondition(sagitta.isFinite, "Sagitta must be finite.")
        precondition(chordLength > 0, "Chord length must be greater than 0.")
        precondition(sagitta > 0, "Sagitta must be greater than 0.")
        precondition(sagitta <= chordLength / 2, "Sagitta must be less than or equal to half of the chord length.")

        radius = (sagitta + (pow(chordLength, 2) / (4 * sagitta))) / 2
    }
}

extension Circle: Shape2D {
    public var body: any Geometry2D {
        @Environment(\.scaledSegmentation) var segmentation
        NodeBasedGeometry(.circle(
            radius: radius,
            segmentCount: segmentation.segmentCount(circleRadius: radius)
        ))
    }
}

public extension Circle {
    static func ellipse(size: Vector2D) -> any Geometry2D {
        let radius = max(size.x, size.y) / 2
        return Circle(radius: radius)
            .scaled(size / radius / 2)
    }

    static func ellipse(x: Double, y: Double) -> any Geometry2D {
        ellipse(size: .init(x, y))
    }
}
