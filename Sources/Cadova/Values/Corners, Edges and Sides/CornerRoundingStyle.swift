import Foundation

/// Represents the style of rounded corners.
public enum CornerRoundingStyle: Sendable, Equatable, Hashable, Codable {
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

    /// A corner shaped using a superellipse curve with a custom exponent.
    ///
    /// This style allows precise control over the curvature of the corner, using a
    /// generalized superellipse defined by the equation `xⁿ + yⁿ = rⁿ`, where `n` is
    /// the exponent. Lower exponents (e.g., 1–2) produce pointier shapes, while higher
    /// values (e.g., 4–6) create flatter, more squared-off corners. At `n = 2`, the shape
    /// is a standard circle. At `n = 4`, it becomes a squircle.
    ///
    /// Note: The same radius will result in visually smaller corners as the exponent increases,
    /// due to the flattening of the curve.
    case superelliptical(exponent: Double)
}

internal extension CornerRoundingStyle {
    var exponent: Double {
        switch self {
        case .circular: 2
        case .squircular: 4
        case .superelliptical(let exponent): exponent
        }
    }

    func polygon(radius: Double, segmentation: EnvironmentValues.Segmentation) -> Polygon {
        let points = switch self {
        case .circular:
            Self.circularCornerPoints(radius: radius, segmentation: segmentation)

        case .squircular:
            Self.squircularCornerPoints(radius: radius, exponent: 4, segmentation: segmentation)

        case .superelliptical (let exponent):
            Self.squircularCornerPoints(radius: radius, exponent: exponent, segmentation: segmentation)
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

    static func squircularCornerPoints(radius: Double, exponent n: Double, segmentation: EnvironmentValues.Segmentation) -> [Vector2D] {
        let segmentCount = segmentation.segmentCount(circleRadius: radius) / 4
        let radius4th = pow(radius, n)

        return (0...segmentCount).map { i -> Vector2D in
            let angle = Double(i) / Double(segmentCount) * 90°
            let x = cos(angle) * radius
            let y = pow(radius4th - pow(x, n), 1.0 / n)
            return Vector2D(x, y)
        }
    }
}

internal struct FilletCorner: Shape2D {
    let size: Vector2D
    @Environment(\.segmentation) private var segmentation
    @Environment(\.cornerRoundingStyle) private var style

    var body: any Geometry2D {
        let radius = max(size.x, size.y)
        let scale = size / radius

        let points = switch style {
        case .circular:
            CornerRoundingStyle.circularCornerPoints(radius: radius, segmentation: segmentation)
        case .squircular, .superelliptical:
            CornerRoundingStyle.squircularCornerPoints(radius: radius, exponent: style.exponent, segmentation: segmentation)
        }

        Polygon(points + [.zero]).scaled(scale)
    }
}
