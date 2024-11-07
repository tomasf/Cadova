import Foundation

internal struct RoundedRectangleMask: Shape2D {
    let size: Vector2D
    let radius: Double
    let corners: Rectangle.Corners
    let style: RoundedCornerStyle

    @Environment(\.facets) var facets

    init(size: Vector2D, radius: Double, corners: Rectangle.Corners, style: RoundedCornerStyle) {
        self.size = size
        self.radius = radius
        self.corners = corners
        self.style = style

        precondition(size.x >= radius * Double(corners.cornerCountAffecting(.x)), "Rectangle is too small to fit rounded corners")
        precondition(size.y >= radius * Double(corners.cornerCountAffecting(.y)), "Rectangle is too small to fit rounded corners")
    }

    var body: any Geometry2D {
        func corner(radius: Double, posX: Bool, posY: Bool) -> Polygon {
            var polygon = style
                .polygon(radius: radius, facets: facets)
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

        return Polygon([
            corner(radius: corners.contains(.minXmaxY) ? radius : 0, posX: false, posY: true),
            corner(radius: corners.contains(.maxXmaxY) ? radius : 0, posX: true, posY: true),
            corner(radius: corners.contains(.maxXminY) ? radius : 0, posX: true, posY: false),
            corner(radius: corners.contains(.minXminY) ? radius : 0, posX: false, posY: false),
        ])
    }
}

