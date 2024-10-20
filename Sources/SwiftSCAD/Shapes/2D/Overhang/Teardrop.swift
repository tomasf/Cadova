import Foundation

/// A teardrop shape used for 3D printing.
///
/// A teardrop shape is often used in place of a circle in 3D printing designs to reduce steep overhangs that are difficult to print.
/// By replacing circular geometry with a teardrop, the design becomes more suitable for printing, especially without the need for support structures.
/// The `bridged` style introduces bridging at the top of the originally intended circle, resulting in a shape that retains a more circular appearance while remaining printable.
///
/// If `Environment.naturalUpDirection` is set, the Teardrop will automatically rotate so that its point or bridge faces upward.
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

        readEnvironment { environment in
            Circle(diameter: diameter)
                .adding {
                    Rectangle(diagonal)
                        .rotated(-angle)
                        .translated(x: -x, y: y)
                        .intersection {
                            Rectangle(diagonal)
                                .rotated(angle + 90°)
                                .translated(x: x, y: y)

                            if style == .bridged {
                                Rectangle(diameter)
                                    .aligned(at: .center)
                            }
                        }
                }
                .rotated(environment.naturalUpDirectionXYAngle.map { $0 - 90° } ?? .zero)
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
