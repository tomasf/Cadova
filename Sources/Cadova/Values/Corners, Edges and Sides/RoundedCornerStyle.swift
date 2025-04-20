import Foundation

/// Represents the style of rounded corners.
public enum RoundedCornerStyle: Sendable {
    /// A regular circular corner.
    case circular
    /// A squircular corner, forming a more natural and continuous curve.
    case squircular
}

internal extension RoundedCornerStyle {
    func polygon(radius: Double, segmentation: EnvironmentValues.Segmentation) -> Polygon {
        switch self {
        case .circular: .circularArc(radius: radius, range: 0°..<90°, segmentation: segmentation)
        case .squircular: .squircleCorner(radius: radius, segmentation: segmentation)
        }
    }
}

internal extension Polygon {
    static func squircleCorner(radius: Double, segmentation: EnvironmentValues.Segmentation) -> Polygon {
        let segmentCount = segmentation.segmentCount(circleRadius: radius)
        let radius4th = pow(radius, 4.0)
        let multiplier = Double.pi / 2.0 / Double(segmentCount)

        return Polygon((0...segmentCount).map { segment -> Vector2D in
            let x = cos(multiplier * Double(segment)) * radius
            let y = pow(radius4th - pow(x, 4.0), 0.25)
            return Vector2D(x, y)
        })
    }
}
