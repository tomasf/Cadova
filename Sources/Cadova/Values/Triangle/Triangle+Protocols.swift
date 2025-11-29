import Foundation

extension Triangle: Shape2D {
    /// Rendering convention:
    /// When rendered as 2D geometry, this type uses a canonical pose for determinism:
    /// - Place vertex A at the origin (0, 0).
    /// - Side `a` lies along the positive X axis; vertex B is at (a, 0).
    /// - Vertex C is placed at (b * cos(alpha), b * sin(alpha)), so that `alpha` is at A and is opposite side `a`.
    public var body: any Geometry2D {
        Polygon([
            .zero,
            Vector2D(a, 0),
            Vector2D(b * cos(gamma), b * sin(gamma))
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
