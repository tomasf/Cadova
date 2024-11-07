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
        func corner(_ corner: Rectangle.Corner) -> Polygon {
            if corners.contains(corner) {
                style.polygon(radius: radius, facets: facets)
                    .transformed(.identity
                        .translated(.init(-radius))
                        .rotated(corner.rotation)
                        .translated(corner.point(boxSize: size))
                    )
            } else {
                .init([corner.point(boxSize: size)])
            }
        }

        return Polygon([corner(.minXminY), corner(.maxXminY), corner(.maxXmaxY), corner(.minXmaxY)])
    }
}

fileprivate extension Rectangle.Corners {
    func cornerCountAffecting(_ axis: Axis2D) -> Int {
        switch axis {
        case .x: (isDisjoint(with: Self.minX) ? 0 : 1) + (isDisjoint(with: Self.maxX) ? 0 : 1)
        case .y: (isDisjoint(with: Self.minY) ? 0 : 1) + (isDisjoint(with: Self.maxY) ? 0 : 1)
        }
    }
}

fileprivate extension Rectangle.Corner {
    var rotation: Angle {
        switch (x, y) {
        case (.negative, .negative): 180°
        case (.positive, .negative): 270°
        case (.positive, .positive): 0°
        case (.negative, .positive): 90°
        }
    }
}
