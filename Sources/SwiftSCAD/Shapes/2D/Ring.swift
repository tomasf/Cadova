import Foundation

/// A `Ring` represents a hollow, two-dimensional circle with specified outer and inner diameters or radii, or thickness.
///
/// You can create a `Ring` by specifying the outer and inner diameters or radii, or by specifying the outer or inner diameter or radius along with the thickness.
///
/// # Example
/// Creating a ring with an outer diameter of 10 and inner diameter of 4:
/// ```swift
/// let ring = Ring(outerDiameter: 10, innerDiameter: 4)
/// ```
public struct Ring: Shape2D {
    private let outerDiameter: Double
    private let innerDiameter: Double

    /// Creates a new `Ring` instance with the specified outer and inner diameters.
    ///
    /// - Parameters:
    ///   - outerDiameter: The outer diameter of the ring. Must be greater than the inner diameter.
    ///   - innerDiameter: The inner diameter of the ring. Must be positive.
    public init(outerDiameter: Double, innerDiameter: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter of the ring must be greater than the inner diameter to allow for a hole")
        precondition(innerDiameter > 0.0, "The inner diameter must be positive")
        precondition(outerDiameter > 0.0, "The outer diameter must be positive")

        self.outerDiameter = outerDiameter
        self.innerDiameter = innerDiameter
    }

    /// Creates a new `Ring` instance with the specified outer and inner radii.
    ///
    /// - Parameters:
    ///   - outerRadius: The outer radius of the ring.
    ///   - innerRadius: The inner radius of the ring.
    public init(outerRadius: Double, innerRadius: Double) {
        self.init(outerDiameter: outerRadius * 2.0, innerDiameter: innerRadius * 2.0)
    }

    /// Creates a new `Ring` instance with the specified outer diameter and thickness.
    ///
    /// - Parameters:
    ///   - outerDiameter: The outer diameter of the ring.
    ///   - thickness: The thickness of the ring.
    public init(outerDiameter: Double, thickness: Double) {
        precondition(outerDiameter > thickness * 2.0, "The outer diameter must be greater than twice the thickness to allow for a hole")
        self.init(outerDiameter: outerDiameter, innerDiameter: outerDiameter - thickness * 2.0)
    }

    /// Creates a new `Ring` instance with the specified inner diameter and thickness.
    ///
    /// - Parameters:
    ///   - innerDiameter: The inner diameter of the ring.
    ///   - thickness: The thickness of the ring.
    public init(innerDiameter: Double, thickness: Double) {
        self.init(outerDiameter: innerDiameter + thickness * 2.0, innerDiameter: innerDiameter)
    }

    /// Creates a new `Ring` instance with the specified outer radius and thickness.
    ///
    /// - Parameters:
    ///   - outerRadius: The outer radius of the ring.
    ///   - thickness: The thickness of the ring.
    public init(outerRadius: Double, thickness: Double) {
        precondition(outerRadius > thickness, "The outer radius must be greater than the thickness to allow for a hole")
        self.init(outerDiameter: outerRadius * 2.0, thickness: thickness)
    }

    /// Creates a new `Ring` instance with the specified inner radius and thickness.
    ///
    /// - Parameters:
    ///   - innerRadius: The inner radius of the ring.
    ///   - thickness: The thickness of the ring.
    public init(innerRadius: Double, thickness: Double) {
        self.init(innerDiameter: innerRadius * 2.0, thickness: thickness)
    }

    /// The geometry representation of the ring.
    public var body: any Geometry2D {
        Circle(diameter: outerDiameter)
            .subtracting {
                Circle(diameter: innerDiameter)
            }
    }
}
