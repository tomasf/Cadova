import Foundation

public extension Rectangle {
    typealias Corner = BoxCorner<Vector2D>
    typealias Corners = Set<Corner>
}

public extension Rectangle.Corner {
    init(x: AxisDirection, y: AxisDirection) {
        self.init(axisDirections: .init(x: x, y: y))
    }

    var x: AxisDirection { axisDirections[.x] }
    var y: AxisDirection { axisDirections[.y] }

    static let minXminY = Self(x: .min, y: .min)
    static let minXmaxY = Self(x: .min, y: .max)
    static let maxXminY = Self(x: .max, y: .min)
    static let maxXmaxY = Self(x: .max, y: .max)

    static let bottomLeft = minXminY
    static let bottomRight = maxXminY
    static let topLeft = minXmaxY
    static let topRight = maxXmaxY
}

public extension Rectangle.Corners {
    static let minXminY: Self = [.minXminY]
    static let minXmaxY: Self = [.minXmaxY]
    static let maxXminY: Self = [.maxXminY]
    static let maxXmaxY: Self = [.maxXmaxY]

    static let bottomLeft = minXminY
    static let bottomRight = maxXminY
    static let topLeft = minXmaxY
    static let topRight = maxXmaxY
}

public extension Rectangle.Corners {
    static let minX: Self = [.minXminY, .minXmaxY]
    static let maxX: Self = [.maxXminY, .maxXmaxY]
    static let minY: Self = [.minXminY, .maxXminY]
    static let maxY: Self = [.minXmaxY, .maxXmaxY]

    static let left = minX
    static let right = maxX
    static let top = maxY
    static let bottom = minY

    static let none: Self = []
    static var all: Self {
        Set(
            AxisDirection.allCases.flatMap { x in
                AxisDirection.allCases.map { y in
                    Rectangle.Corner(x: x, y: y)
                }
            }
        )
    }
}
