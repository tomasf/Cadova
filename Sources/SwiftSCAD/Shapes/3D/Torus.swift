import Foundation

/// A three-dimensional donut shape formed by revolving a circle about the Z axis.
public struct Torus: Shape3D {
    /// The radius of the tube.
    private let minorRadius: Double

    /// The distance from the center of the tube to the center of the torus.
    private let majorRadius: Double

    public init(minorRadius: Double, majorRadius: Double) {
        precondition(majorRadius >= minorRadius, "The major radius must be greater than or equal to the minor radius")
        self.minorRadius = minorRadius
        self.majorRadius = majorRadius
    }

    public init(innerDiameter: Double, outerDiameter: Double) {
        precondition(outerDiameter > innerDiameter, "The outer diameter must be greater than the inner diameter")
        let tubeDiameter = (outerDiameter - innerDiameter) / 2.0
        self.init(minorRadius: tubeDiameter / 2.0, majorRadius: innerDiameter / 2.0 + tubeDiameter / 2.0)
    }

    public init(innerDiameter: Double, tubeRadius: Double) {
        self.init(minorRadius: tubeRadius, majorRadius: innerDiameter / 2.0 + tubeRadius)
    }

    public init(innerDiameter: Double, tubeDiameter: Double) {
        self.init(minorRadius: tubeDiameter / 2.0, majorRadius: innerDiameter / 2.0 + tubeDiameter / 2.0)
    }

    public init(outerDiameter: Double, tubeRadius: Double) {
        precondition(outerDiameter >= tubeRadius * 4.0, "The outer diameter must be at least four times as large as the tube radius")
        self.init(minorRadius: tubeRadius, majorRadius: outerDiameter / 2.0 - tubeRadius)
    }

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
