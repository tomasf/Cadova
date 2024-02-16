import Foundation

/// A teardrop shape used for 3D printing.
///
/// A teardrop is commonly used in place of a circle in 3D printing designs where the top of the circle would have a steep overhang.
/// By replacing the circular geometry with a teardrop, it becomes more suitable for printing, especially without support structures.
/// The `bridged` style employs bridging at the top of the originally intended circle, creating a more circle-like shape while still being printable.
///
/// ```
/// // Example of creating a teardrop shape with a diameter of 10, angle of 30°, and full style.
/// let teardrop = Teardrop(diameter: 10, angle: 30°, style: .full)
/// ```


public struct Teardrop: Shape2D {
    public let style: Style
    public let angle: Angle
    public let diameter: Double

    /// Creates a teardrop shape with a specific diameter, angle, and style.
    /// - Parameters:
    ///   - diameter: The diameter of the circular part of the teardrop.
    ///   - angle: The angle of the point of the teardrop. Defaults to 45 degrees.
    ///   - style: Specifies the style of the teardrop. Defaults to `.full`.
    public init(diameter: Double, angle: Angle = 45°, style: Style = .full) {
        precondition(angle > 0° && angle < 90°, "Angle must be between 0 and 90 degrees")
        self.diameter = diameter
        self.angle = angle
        self.style = style
    }

    public var body: any Geometry2D {
        let x = cos(angle) * diameter/2
        let y = sin(angle) * diameter/2
        let diagonal = diameter / sin(angle)

        let base = Union {
            Circle(diameter: diameter)

            Rectangle([diagonal, diagonal])
                .rotated(-angle)
                .translated(x: -x, y: y)
                .intersection {
                    Rectangle([diagonal, diagonal])
                        .rotated(angle + 90°)
                        .translated(x: x, y: y)
                }
        }

        if style == .bridged {
            return base.intersection {
                Rectangle([diameter, diameter], center: .xy)
            }
        } else {
            return base
        }
    }

    /// Defines the style of a teardrop shape.
    public enum Style {
        /// A complete teardrop shape where steep overhangs need to be avoided.
        case full
        /// A teardrop shape with a "bridge" at the top of the originally intended circle, creating a more circle-like appearance while keeping it printable.
        case bridged
    }
}
