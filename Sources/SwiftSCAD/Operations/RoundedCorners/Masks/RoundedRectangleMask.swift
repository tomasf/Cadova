import Foundation

internal struct RoundedRectangleMask: Shape2D {
    private let radii: RectangleCornerRadii
    let size: Vector2D
    let cornerStyle: RoundedCornerStyle

    internal init(_ size: Vector2D, style cornerStyle: RoundedCornerStyle, radii: RectangleCornerRadii) {
        self.size = size
        self.radii = radii
        self.cornerStyle = cornerStyle

        radii.validateForSize(size)
    }

    public var body: any Geometry2D {
        func corner(radius: Double, posX: Bool, posY: Bool, environment: EnvironmentValues) -> Polygon {
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

        return readEnvironment { e in
            Polygon([
                corner(radius: radii.minXmaxY, posX: false, posY: true, environment: e),
                corner(radius: radii.maxXmaxY, posX: true, posY: true, environment: e),
                corner(radius: radii.maxXminY, posX: true, posY: false, environment: e),
                corner(radius: radii.minXminY, posX: false, posY: false, environment: e),
            ])
        }
    }
}

