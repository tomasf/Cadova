import Foundation

/// A hollow, two-dimensional circle.
public struct Ring: Shape2D {
    private let outerDiameter: Double
    private let innerDiameter: Double

    public init(outerDiameter: Double, innerDiameter: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter of the ring must be greater than the inner diameter to allow for a hole")
        precondition(innerDiameter > 0.0, "The inner diameter must be positive")
        precondition(outerDiameter > 0.0, "The outer diameter must be positive")

        self.outerDiameter = outerDiameter
        self.innerDiameter = innerDiameter
    }

    public init(outerRadius: Double, innerRadius: Double) {
        self.init(outerDiameter: outerRadius * 2.0, innerDiameter: innerRadius * 2.0)
    }

    public init(outerDiameter: Double, thickness: Double) {
        precondition(outerDiameter > thickness * 2.0, "The outer diameter must be greater than twice the thickness to allow for a hole")
        self.init(outerDiameter: outerDiameter, innerDiameter: outerDiameter - thickness * 2.0)
    }

    public init(innerDiameter: Double, thickness: Double) {
        self.init(outerDiameter: innerDiameter + thickness * 2.0, innerDiameter: innerDiameter)
    }

    public init(outerRadius: Double, thickness: Double) {
        precondition(outerRadius > thickness, "The outer radius must be greater than the thickness to allow for a hole")
        self.init(outerDiameter: outerRadius * 2.0, thickness: thickness)
    }

    public init(innerRadius: Double, thickness: Double) {
        self.init(innerDiameter: innerRadius * 2.0, thickness: thickness)
    }

    public var body: Geometry2D {
        Circle(diameter: outerDiameter)
            .subtracting {
                Circle(diameter: innerDiameter)
            }
    }
}
