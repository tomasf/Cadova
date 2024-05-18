import Foundation

/// Represents the style of rounded corners.
public enum RoundedCornerStyle {
    /// A regular circular corner.
    case circular
    /// A squircular corner, forming a more natural and continuous curve.
    case squircular
}

internal extension RoundedCornerStyle {
    func polygon(radius: Double, in environment: Environment) -> Polygon {
        switch self {
        case .circular: .circularArc(radius: radius, range: 0°..<90°, facets: environment.facets)
        case .squircular: .squircleCorner(radius: radius, facets: environment.facets)
        }
    }
}

internal extension Polygon {
    static func squircleCorner(radius: Double, facets: Environment.Facets) -> Polygon {
        let facetCount = facets.facetCount(circleRadius: radius)
        let radius4th = pow(radius, 4.0)

        return Polygon((0...facetCount).map { facet -> Vector2D in
            let x = cos(.pi / 2.0 / Double(facetCount) * Double(facet)) * radius
            let y = pow(radius4th - pow(x, 4.0), 0.25)
            return Vector2D(x, y)
        })
    }
}
