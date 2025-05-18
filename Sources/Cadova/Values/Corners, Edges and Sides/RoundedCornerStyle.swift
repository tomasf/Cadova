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
        let points = switch self {
        case .circular: Self.circularCornerPoints(radius: radius, segmentation: segmentation)
        case .squircular: Self.squircularCornerPoints(radius: radius, segmentation: segmentation)
        }
        return Polygon(points)
    }

    static func circularCornerPoints(radius: Double, segmentation: EnvironmentValues.Segmentation) -> [Vector2D] {
        let segmentCount = segmentation.segmentCount(arcRadius: radius, angle: 90°)

        return (0...segmentCount).map { i -> Vector2D in
            let angle = Double(i) / Double(segmentCount) * 90°
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    static func squircularCornerPoints(radius: Double, segmentation: EnvironmentValues.Segmentation) -> [Vector2D] {
        let segmentCount = segmentation.segmentCount(circleRadius: radius) / 4
        let radius4th = pow(radius, 4.0)
        let multiplier = Double.pi / 2.0 / Double(segmentCount)

        return (0...segmentCount).map { segment -> Vector2D in
            let x = cos(multiplier * Double(segment)) * radius
            let y = pow(radius4th - x * x * x * x, 0.25)
            return Vector2D(x, y)
        }
    }
}

internal struct SquircularCorner: Shape2D {
    let radius: Double
    @Environment(\.segmentation) private var segmentation

    var body: any Geometry2D {
        Polygon(RoundedCornerStyle.squircularCornerPoints(radius: radius, segmentation: segmentation) + [.zero])
    }
}
