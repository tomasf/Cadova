import Foundation

/// Represents the style of rounded corners.
public enum RoundedCornerStyle {
    /// A regular circular corner.
    case circular
    /// A squircular corner, forming a more natural and continuous curve.
    case squircular
}

internal struct RectangleCornerRadii {
    public let minXminY: Double
    public let maxXminY: Double
    public let maxXmaxY: Double
    public let minXmaxY: Double

    init(_ minXminY: Double, _ maxXminY: Double, _ maxXmaxY: Double, _ minXmaxY: Double) {
        self.minXminY = minXminY
        self.maxXminY = maxXminY
        self.maxXmaxY = maxXmaxY
        self.minXmaxY = minXmaxY
    }

    init(_ value: Double) {
        self.init(value, value, value, value)
    }

    func validateForSize(_ size: Vector2D) {
        precondition(
            minXminY + maxXminY <= size.x
            && minXmaxY + maxXmaxY <= size.x
            && minXmaxY + minXminY <= size.y
            && maxXmaxY + maxXminY <= size.y,
            "Rounded rectangle corners are too big to fit within rectangle size"
        )
    }
}
