import Foundation

/// A hollow, three-dimensional cylinder with specified inner and outer diameters and height.
public struct Tube: Shape3D {
    private let outerDiameter: Double
    private let innerDiameter: Double
    private let height: Double

    /// Creates a tube with specified outer and inner diameters and height.
    /// - Parameters:
    ///   - outerDiameter: The outer diameter of the tube. Must be greater than the inner diameter.
    ///   - innerDiameter: The inner diameter of the tube. Must be a positive value.
    ///   - height: The height of the tube.
    public init(outerDiameter: Double, innerDiameter: Double, height: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter of the ring must be greater than the inner diameter to allow for a hole")
        precondition(innerDiameter > 0.0, "The inner diameter must be positive")
        precondition(outerDiameter > 0.0, "The outer diameter must be positive")

        self.outerDiameter = outerDiameter
        self.innerDiameter = innerDiameter
        self.height = height
    }

    /// Creates a tube with specified outer and inner radii and height.
    /// - Parameters:
    ///   - outerRadius: The outer radius of the tube.
    ///   - innerRadius: The inner radius of the tube.
    ///   - height: The height of the tube.
    public init(outerRadius: Double, innerRadius: Double, height: Double) {
        self.init(outerDiameter: outerRadius * 2.0, innerDiameter: innerRadius * 2.0, height: height)
    }

    /// Creates a tube with a specified outer diameter, wall thickness, and height.
    /// - Parameters:
    ///   - outerDiameter: The outer diameter of the tube.
    ///   - thickness: The thickness of the tube wall.
    ///   - height: The height of the tube.
    public init(outerDiameter: Double, thickness: Double, height: Double) {
        precondition(outerDiameter > thickness * 2.0, "The outer diameter must be greater than twice the thickness to allow for a hole")
        self.init(outerDiameter: outerDiameter, innerDiameter: outerDiameter - thickness * 2.0, height: height)
    }

    /// Creates a tube with a specified inner diameter, wall thickness, and height.
    /// - Parameters:
    ///   - innerDiameter: The inner diameter of the tube.
    ///   - thickness: The thickness of the tube wall.
    ///   - height: The height of the tube.
    public init(innerDiameter: Double, thickness: Double, height: Double) {
        self.init(outerDiameter: innerDiameter + thickness * 2.0, innerDiameter: innerDiameter, height: height)
    }

    /// Creates a tube with a specified outer radius, wall thickness, and height.
    /// - Parameters:
    ///   - outerRadius: The outer radius of the tube.
    ///   - thickness: The thickness of the tube wall.
    ///   - height: The height of the tube.
    public init(outerRadius: Double, thickness: Double, height: Double) {
        precondition(outerRadius > thickness, "The outer diameter must be greater than the thickness to allow for a hole")
        self.init(outerDiameter: outerRadius * 2.0, thickness: thickness, height: height)
    }

    /// Creates a tube with a specified inner radius, wall thickness, and height.
    /// - Parameters:
    ///   - innerRadius: The inner radius of the tube.
    ///   - thickness: The thickness of the tube wall.
    ///   - height: The height of the tube.
    public init(innerRadius: Double, thickness: Double, height: Double) {
        self.init(innerDiameter: innerRadius * 2.0, thickness: thickness, height: height)
    }

    public var body: any Geometry3D {
        Ring(outerDiameter: outerDiameter, innerDiameter: innerDiameter)
            .extruded(height: height)
    }
}
