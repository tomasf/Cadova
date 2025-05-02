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
        case .circular: .circleCorner(radius: radius, segmentation: segmentation)
        case .squircular: .squircleCorner(radius: radius, segmentation: segmentation)
        }
    }
}

fileprivate extension Polygon {
    static func circleCorner(radius: Double, segmentation: EnvironmentValues.Segmentation) -> Self {
        let segmentCount = segmentation.segmentCount(arcRadius: radius, angle: 90°)

        return Polygon((0...segmentCount).map { i -> Vector2D in
            let angle = Double(i) / Double(segmentCount) * 90°
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        })
    }

    static func squircleCorner(radius: Double, segmentation: EnvironmentValues.Segmentation) -> Self {
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
