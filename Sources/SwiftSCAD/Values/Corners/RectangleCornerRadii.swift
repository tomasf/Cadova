import Foundation

internal struct RectangleCornerRadii {
    let minXminY: Double
    let maxXminY: Double
    let maxXmaxY: Double
    let minXmaxY: Double

    init(_ minXminY: Double, _ maxXminY: Double, _ maxXmaxY: Double, _ minXmaxY: Double) {
        self.minXminY = minXminY
        self.maxXminY = maxXminY
        self.maxXmaxY = maxXmaxY
        self.minXmaxY = minXmaxY
    }

    init(_ value: Double, corners: RectangleCorners) {
        self.init(
            corners.contains(.bottomLeft) ? value : 0,
            corners.contains(.bottomRight) ? value : 0,
            corners.contains(.topRight) ? value : 0,
            corners.contains(.topLeft) ? value : 0
        )
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
