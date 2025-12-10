import Foundation

/// A hollow, three-dimensional cylinder with specified inner and outer diameters and height.
public struct Tube: Shape3D {
    /// The outer diameter of the tube.
    public let outerDiameter: Double

    /// The inner diameter of the tube (the hole).
    public let innerDiameter: Double

    /// The height of the tube along the Z axis.
    public let height: Double

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
        ring.extruded(height: height)
    }
}

public extension Tube {
    /// The vertical cross-section of the tube
    var ring: Ring {
        Ring(outerDiameter: outerDiameter, innerDiameter: innerDiameter)
    }

    /// The outer radius of the tube.
    var outerRadius: Double { outerDiameter / 2 }

    /// The inner radius of the tube.
    var innerRadius: Double { innerDiameter / 2 }

    /// The lateral surface area of the tube (cylindrical surfaces).
    var lateralSurfaceArea: Double {
        let outer = .pi * outerDiameter * height
        let inner = .pi * innerDiameter * height
        return outer + inner
    }

    /// The area of the top or bottom face (ring area).
    var ringFaceArea: Double {
        .pi * (outerRadius * outerRadius - innerRadius * innerRadius)
    }

    /// The total surface area of the tube (outer + inner sides + two ring faces).
    var surfaceArea: Double {
        lateralSurfaceArea + ringFaceArea * 2
    }

    /// The volume enclosed by the tube wall.
    var volume: Double {
        ringFaceArea * height
    }
}
