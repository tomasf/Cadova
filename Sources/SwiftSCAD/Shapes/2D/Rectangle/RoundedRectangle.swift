import Foundation

/// A 2D shape that represents a rectangle with rounded corners.
///
/// You can create a `RoundedRectangle` with either a circular or squircular corner style.
/// A squircular corner forms a more natural and continuous curve than a circular corner.
///
/// # Example
/// ```swift
/// RoundedRectangle([100, 50], style: .circular, cornerRadius: 10)
/// ```
public struct RoundedRectangle: Shape2D {
    private let radii: RectangleCornerRadii
    let size: Vector2D
    let cornerStyle: RoundedCornerStyle

    internal init(_ size: Vector2D, style cornerStyle: RoundedCornerStyle, radii: RectangleCornerRadii) {
        self.size = size
        self.radii = radii
        self.cornerStyle = cornerStyle

        radii.validateForSize(size)
    }

    /// Creates a rounded rectangle with a specific corner style and uniform radius for all corners.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle.
    ///   - style: The style of the corners, either circular or squircular.
    ///   - cornerRadius: The radius of the corners.
    public init(_ size: Vector2D, style: RoundedCornerStyle = .circular, cornerRadius: Double) {
        self.init(size, style: style, radii: .init(cornerRadius))
    }

    /// Creates a rounded rectangle with a specific corner style and radii.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle.
    ///   - style: The style of the corners, either circular or squircular.
    ///   - cornerRadii: An array containing the radii of the four corners.
    public init(
        _ size: Vector2D,
        style: RoundedCornerStyle = .circular,
        cornerRadii a: Double,
        _ b: Double,
        _ c: Double,
        _ d: Double
    ) {
        self.init(size, style: style, radii: .init(a, b, c, d))
    }

    /// Creates a rounded rectangle with a specific corner style and individual radii for each corner.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle.
    ///   - style: The style of the corners, either circular or squircular.
    ///   - minXminY: The radius of the bottom-left corner.
    ///   - maxXminY: The radius of the bottom-right corner.
    ///   - maxXmaxY: The radius of the top-right corner.
    ///   - minXmaxY: The radius of the top-left corner.
    public init(
        _ size: Vector2D,
        style: RoundedCornerStyle = .circular,
        minXminY: Double = 0,
        maxXminY: Double = 0,
        maxXmaxY: Double = 0,
        minXmaxY: Double = 0
    ) {
        self.init(size, style: style, radii: .init(minXminY, maxXminY, maxXmaxY, minXmaxY))
    }

    public var body: any Geometry2D {
        func corner(radius: Double, posX: Bool, posY: Bool, environment: Environment) -> Polygon {
            var polygon = cornerStyle
                .polygon(radius: radius, in: environment)
                .transformed(.identity
                    .translated([size.x / 2 - radius, size.y / 2 - radius])
                    .scaled(x: posX ? 1 : -1, y: posY ? 1 : -1)
                    .translated([size.x / 2, size.y / 2])
                )

            if posX == posY {
                polygon = polygon.reversed()
            }
            return polygon
        }

        return EnvironmentReader { e in
            Polygon([
                corner(radius: radii.minXmaxY, posX: false, posY: true, environment: e),
                corner(radius: radii.maxXmaxY, posX: true, posY: true, environment: e),
                corner(radius: radii.maxXminY, posX: true, posY: false, environment: e),
                corner(radius: radii.minXminY, posX: false, posY: false, environment: e),
            ])
        }
    }
}

private extension RoundedCornerStyle {
    func polygon(radius: Double, in environment: Environment) -> Polygon {
        switch self {
        case .circular: .circularArc(radius: radius, range: 0°..<90°, facets: environment.facets)
        case .squircular: .squircleCorner(radius: radius, facets: environment.facets)
        }
    }
}

private extension Polygon {
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
