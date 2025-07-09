import Foundation

public extension Rectangle {
    /// A type representing one of the four corners of a 2D rectangle.
    ///
    /// Each corner is defined by a combination of minimum or maximum positions along the X and Y axes. For example,
    /// `.minXminY` refers to the corner with the smallest X and Y coordinates.
    ///
    typealias Corner = OrthogonalCorner<D2>
    typealias Corners = Set<Corner>
}

public extension Rectangle.Corner {
    /// Creates a rectangle corner from explicit axis directions.
    ///
    /// - Parameters:
    ///   - x: The linear direction for the X axis (`.min` or `.max`).
    ///   - y: The linear direction for the Y axis.
    ///
    init(x: LinearDirection, y: LinearDirection) {
        self.init(axisDirections: .init(x: x, y: y))
    }

    /// The X axis direction of this corner.
    var x: LinearDirection { axisDirections[.x] }

    /// The Y axis direction of this corner.
    var y: LinearDirection { axisDirections[.y] }


    /// The corner at the minimum X and Y coordinates.
    static let minXminY = Self(x: .min, y: .min)

    /// The corner at the minimum X and maximum Y coordinates.
    static let minXmaxY = Self(x: .min, y: .max)

    /// The corner at the maximum X and minimum Y coordinates.
    static let maxXminY = Self(x: .max, y: .min)

    /// The corner at the maximum X and maximum Y coordinates.
    static let maxXmaxY = Self(x: .max, y: .max)


    /// The bottom-left corner (minX, minY).
    static let bottomLeft = minXminY

    /// The bottom-right corner (maxX, minY).
    static let bottomRight = maxXminY

    /// The top-left corner (minX, maxY).
    static let topLeft = minXmaxY

    /// The top-right corner (maxX, maxY).
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
            LinearDirection.allCases.flatMap { x in
                LinearDirection.allCases.map { y in
                    Rectangle.Corner(x: x, y: y)
                }
            }
        )
    }
}
