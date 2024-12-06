import Foundation

/// Represents a three-dimensional torus (donut shape) defined by revolving a circle around the Z axis.
///
/// A `Torus` is characterized by two primary parameters: a major radius and a minor radius. The major radius determines the distance from the center of the torus to the center of the tube, while the minor radius defines the radius of the tube itself.

public struct Torus: Shape3D {
    /// The radius of the tube.
    private let minorRadius: Double

    /// The distance from the center of the tube to the center of the torus.
    private let majorRadius: Double

    /// Initializes a new torus with specified minor and major radii.
    ///
    /// - Parameters:
    ///   - minorRadius: The radius of the tube (minor radius of the torus).
    ///   - majorRadius: The distance from the center of the torus to the center of the tube (major radius of the torus).
    /// - Precondition: The major radius must be greater than or equal to the minor radius to form a valid torus.
    public init(minorRadius: Double, majorRadius: Double) {
        precondition(majorRadius >= minorRadius, "The major radius must be greater than or equal to the minor radius")
        self.minorRadius = minorRadius
        self.majorRadius = majorRadius
    }

    /// Initializes a new torus with specified inner and outer diameters.
    ///
    /// This initializer calculates the appropriate minor and major radii based on the provided diameters, facilitating an alternative way of defining the torus dimensions.
    ///
    /// - Parameters:
    ///   - innerDiameter: The inner diameter of the torus, corresponding to the diameter of the hole at its center.
    ///   - outerDiameter: The outer diameter of the torus, measuring the entire span from one outer edge to the opposite outer edge.
    /// - Precondition: The outer diameter must be greater than the inner diameter to ensure a valid toroidal shape.
    public init(innerDiameter: Double, outerDiameter: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter must be greater than the inner diameter")
        let tubeDiameter = (outerDiameter - innerDiameter) / 2.0
        self.init(minorRadius: tubeDiameter / 2.0, majorRadius: innerDiameter / 2.0 + tubeDiameter / 2.0)
    }

    /// Initializes a torus with a specified inner diameter and tube radius.
    ///
    /// This initializer allows for defining the torus by specifying the diameter of the central hole and the radius of the torus tube directly.
    ///
    /// - Parameters:
    ///   - innerDiameter: The diameter of the torus' central hole.
    ///   - tubeRadius: The radius of the torus tube.
    public init(innerDiameter: Double, tubeRadius: Double) {
        self.init(minorRadius: tubeRadius, majorRadius: innerDiameter / 2.0 + tubeRadius)
    }

    /// Initializes a torus with a specified inner diameter and tube diameter.
    ///
    /// This method offers an alternative way of specifying the torus size, focusing on the tube's thickness and the central hole's diameter.
    ///
    /// - Parameters:
    ///   - innerDiameter: The diameter of the hole in the center of the torus.
    ///   - tubeDiameter: The diameter of the torus tube.
    public init(innerDiameter: Double, tubeDiameter: Double) {
        self.init(minorRadius: tubeDiameter / 2.0, majorRadius: innerDiameter / 2.0 + tubeDiameter / 2.0)
    }

    /// Initializes a torus with a specified outer diameter and tube radius.
    ///
    /// This initializer allows for defining the torus size based on the total external diameter and the thickness of the torus tube.
    ///
    /// - Parameters:
    ///   - outerDiameter: The total diameter of the torus, from one outer edge to the opposite outer edge.
    ///   - tubeRadius: The radius of the torus tube.
    /// - Precondition: `outerDiameter` must be at least four times the tube radius to form a valid torus.
    public init(outerDiameter: Double, tubeRadius: Double) {
        precondition(outerDiameter >= tubeRadius * 4.0, "The outer diameter must be at least four times as large as the tube radius")
        self.init(minorRadius: tubeRadius, majorRadius: outerDiameter / 2.0 - tubeRadius)
    }

    /// Initializes a torus with a specified outer diameter and tube diameter.
    ///
    /// This initializer offers another approach to defining the torus dimensions, focusing on the outermost diameter and the tube's overall thickness.
    ///
    /// - Parameters:
    ///   - outerDiameter: The total diameter of the torus, from one outer edge to the opposite outer edge.
    ///   - tubeDiameter: The diameter of the torus tube.
    /// - Precondition: `outerDiameter` must be at least twice as large as the tube diameter to ensure a proper toroidal form.
    public init(outerDiameter: Double, tubeDiameter: Double) {
        precondition(outerDiameter >= tubeDiameter * 2.0, "The outer diameter must be at least twice as large as the tube diameter")
        self.init(minorRadius: tubeDiameter / 2.0, majorRadius: outerDiameter / 2.0 - tubeDiameter / 2.0)
    }

    public var body: any Geometry3D {
        Circle(radius: minorRadius)
            .translated(x: majorRadius, y: minorRadius)
            .extruded(angles: 0°..<360°)
    }
}
