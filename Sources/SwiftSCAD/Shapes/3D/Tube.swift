import Foundation

/// A hollow, three-dimensional cylinder with a fixed inner and outer diameter.
public struct Tube: Shape3D {
    private let outerDiameter: Double
    private let innerDiameter: Double
    private let height: Double

    public init(outerDiameter: Double, innerDiameter: Double, height: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter of the ring must be greater than the inner diameter to allow for a hole")
        precondition(innerDiameter > 0.0, "The inner diameter must be positive")
        precondition(outerDiameter > 0.0, "The outer diameter must be positive")

        self.outerDiameter = outerDiameter
        self.innerDiameter = innerDiameter
        self.height = height
    }

    public init(outerRadius: Double, innerRadius: Double, height: Double) {
        self.init(outerDiameter: outerRadius * 2.0, innerDiameter: innerRadius * 2.0, height: height)
    }

    public init(outerDiameter: Double, thickness: Double, height: Double) {
        precondition(outerDiameter > thickness * 2.0, "The outer diameter must be greater than twice the thickness to allow for a hole")
        self.init(outerDiameter: outerDiameter, innerDiameter: outerDiameter - thickness * 2.0, height: height)
    }

    public init(innerDiameter: Double, thickness: Double, height: Double) {
        self.init(outerDiameter: innerDiameter + thickness * 2.0, innerDiameter: innerDiameter, height: height)
    }

    public init(outerRadius: Double, thickness: Double, height: Double) {
        precondition(outerRadius > thickness, "The outer diameter must be greater than the thickness to allow for a hole")
        self.init(outerDiameter: outerRadius * 2.0, thickness: thickness, height: height)
    }

    public init(innerRadius: Double, thickness: Double, height: Double) {
        self.init(innerDiameter: innerRadius * 2.0, thickness: thickness, height: height)
    }

    public var body: Geometry3D {
        Ring(outerDiameter: outerDiameter, innerDiameter: innerDiameter)
            .extruded(height: height)
    }
}
