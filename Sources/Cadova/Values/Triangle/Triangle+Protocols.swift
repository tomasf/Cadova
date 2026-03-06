import Foundation

extension Triangle: Shape2D {
    /// Rendering convention:
    /// When rendered as 2D geometry, this type uses a canonical pose for determinism:
    /// - Vertex A is at the origin (0, 0).
    /// - Vertex B is at (c, 0), so side `c` (= AB) lies along the positive X axis.
    /// - Vertex C is at (b · cos(α), b · sin(α)), placing angle `alpha` at A.
    public var body: any Geometry2D {
        Polygon([
            .zero,
            Vector2D(c, 0),
            Vector2D(b * cos(alpha), b * sin(alpha))
        ])
    }
}

extension Triangle: Area, Perimeter {
    /// The area of the triangle
    public var area: Double {
        let s = (a + b + c) / 2
        return sqrt(max(0, s * (s - a) * (s - b) * (s - c)))
    }

    /// The perimeter of the triangle
    public var perimeter: Double { a + b + c }

    /// The inradius (radius of the inscribed circle)
    public var inradius: Double { (2 * area) / perimeter }

    /// The circumradius (radius of the circumscribed circle)
    public var circumradius: Double { a / (2 * sin(alpha)) }
}
