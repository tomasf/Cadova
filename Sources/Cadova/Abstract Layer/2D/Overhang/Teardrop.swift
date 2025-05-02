import Foundation

/// A teardrop shape optimized for FDM 3D printing, used to replace circular features with printable overhangs.
///
/// This shape reduces steep overhangs that occur in circular cutouts, making it more suitable for FDM printing without supports.
/// The top of the shape can either be pointed or flat (bridgeable).
///
/// If `EnvironmentValues.naturalUpDirection` is set, the shape automatically rotates so that the tip or flat bridge faces upward.
///
/// This shape is commonly used for holes or cutouts where mechanical function is preserved but steep overhangs need to be avoided.
///
public struct Teardrop: Shape2D {
    private let style: Style
    private let angle: Angle
    private let radius: Double

    @Environment(\.naturalUpDirectionXYAngle) private var upAngle

    /// Creates a teardrop shape with a given radius, overhang angle, and visual style.
    ///
    /// - Parameters:
    ///   - radius: The radius of the shape (typically replacing a circular hole of this size).
    ///   - angle: The overhang angle, or half the point angle. Lower values create sharper tips.
    ///            The default of 45° is typically a safe starting point for most FDM printers.
    ///   - style: The top style: `.pointed` (sharp) or `.flat` (bridged). Defaults to `.pointed`.
    ///
    public init(radius: Double, overhang angle: Angle = 45°, style: Style = .pointed) {
        precondition(angle > 0° && angle <= 90°, "Angle must be between 0 and 90 degrees")
        self.radius = radius
        self.angle = angle
        self.style = style
    }

    /// Creates a teardrop shape with a given diameter, overhang angle, and visual style.
    ///
    /// - Parameters:
    ///   - diameter: The full width of the shape (typically replacing a circular hole of this size).
    ///   - angle: The overhang angle, or half the point angle. Lower values create sharper tips.
    ///            The default of 45° is typically a safe starting point for most FDM printers.
    ///   - style: The top style: `.pointed` (sharp) or `.flat` (bridged). Defaults to `.pointed`.
    ///
    public init(diameter: Double, overhang angle: Angle = 45°, style: Style = .pointed) {
        self.init(radius: diameter / 2, overhang: angle, style: style)
    }

    public var body: any Geometry2D {
        Intersection {
            Circle(radius: radius)
                .convexHull(adding: [0, radius / sin(angle)])

            if style == .flat {
                Rectangle(radius * 2)
                    .aligned(at: .center)
            }
        }
        .rotated(upAngle.map { $0 - 90° } ?? .zero)
    }

    /// Defines the top shape of a teardrop used for 3D printing.
    public enum Style: Sendable {
        /// A pointed top that forms a complete teardrop, optimal for minimizing steep overhangs.
        case pointed

        /// A flat, bridgeable top that retains more of the circular appearance while remaining printable.
        case flat
    }
}
