import Foundation

/// Represents the style of rounded corners.
public enum RoundedCornerStyle: Sendable {
    /// A regular circular corner.
    ///
    /// This style uses a quarter-circle arc to round corners, producing the classic
    /// appearance commonly seen in UI design and general modeling. It is simple, smooth,
    /// and predictable in shape.
    case circular

    /// A squircular corner, forming a more natural and continuous curve.
    ///
    /// This style uses a squircle profile, which is smoother and more gradual than a circular arc.
    /// It follows a superellipse curve defined by `x⁴ + y⁴ = r⁴`, providing a softer transition
    /// from edge to corner. This can look more organic and balanced, especially at larger radii.
    /// Because of the flatter profile near the edges, squircular corners visually appear smaller
    /// than circular ones at the same radius.
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

        return (0...segmentCount).map { i -> Vector2D in
            let angle = Double(i) / Double(segmentCount) * 90°
            let x = cos(angle) * radius
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
