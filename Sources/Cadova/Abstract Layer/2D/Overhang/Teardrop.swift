import Foundation

/// A teardrop shape optimized for FDM 3D printing, used to replace circular features with printable overhangs.
///
/// This shape reduces steep overhangs that occur in circular cutouts, making it more suitable for FDM printing without supports.
/// The top of the shape can either be pointed or flat (bridgeable).
///
/// The overhang angle for this shape is determined from the environment (`overhangAngle`, default 45°). To set a custom overhang
/// angle for your geometry, use `.withOverhangAngle(_:)` on your geometry. If `EnvironmentValues.naturalUpDirection` is set, the
/// shape automatically rotates so that the tip or flat bridge faces upward.
///
/// This shape is commonly used for holes or cutouts where mechanical function is preserved but steep overhangs need to be avoided.
///
/// When used in additive operations, the teardrop shape is automatically oriented with its point facing downward. This orientation improves printability by minimizing unsupported overhangs and taking advantage of gravity. In subtractive operations, such as cutouts, the shape is rotated to face upward to ensure optimal bridging or point clearance at the top of the cavity.
///
public struct Teardrop: Shape2D {
    private let style: Style
    private let radius: Double

    @Environment(\.naturalUpDirectionXYAngle) private var upAngle
    @Environment(\.overhangAngle) private var overhangAngle
    @Environment(\.operation) private var operation

    /// Creates a teardrop shape with a given radius and visual style.
    ///
    /// The overhang angle is determined from the environment using the `overhangAngle` value (default 45°).
    /// To set the overhang angle, use `.withOverhangAngle(_:)` on your geometry.
    ///
    /// - Parameters:
    ///   - radius: The radius of the shape (typically replacing a circular hole of this size).
    ///   - style: The top style: `.pointed` (sharp) or `.flat` (bridged). Defaults to `.pointed`.
    ///
    public init(radius: Double, style: Style = .pointed) {
        self.radius = radius
        self.style = style
    }

    /// Creates a teardrop shape with a given diameter and visual style.
    ///
    /// The overhang angle is determined from the environment using the `overhangAngle` value (default 45°).
    /// To set the overhang angle, use `.withOverhangAngle(_:)` on your geometry.
    ///
    /// - Parameters:
    ///   - diameter: The full width of the shape (typically replacing a circular hole of this size).
    ///   - style: The top style: `.pointed` (sharp) or `.flat` (bridged). Defaults to `.pointed`.
    ///
    public init(diameter: Double, style: Style = .pointed) {
        self.init(radius: diameter / 2, style: style)
    }

    public var body: any Geometry2D {
        Intersection {
            Circle(radius: radius)
                .convexHull(adding: [0, radius / sin(overhangAngle)])

            if style == .flat {
                Rectangle(radius * 2)
                    .aligned(at: .center)
            }
        }
        .rotated(upAngle.map { $0 - (operation == .subtraction ? 90° : -90°) } ?? .zero)
    }

    /// Defines the top shape of a teardrop used for 3D printing.
    public enum Style: Sendable {
        /// A pointed top that forms a complete teardrop, optimal for minimizing steep overhangs.
        case pointed

        /// A flat, bridgeable top that retains more of the circular appearance while remaining printable.
        case flat
    }
}
