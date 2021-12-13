import Foundation

/// A regular convex polygon
public struct RegularPolygon: Shape2D {
    public let sideCount: Int
    public let circumradius: Double

    public init(sideCount: Int, circumradius: Double) {
        precondition(sideCount >= 3)
        precondition(circumradius > 0)
        self.sideCount = sideCount
        self.circumradius = circumradius
    }

    public init(sideCount: Int, apothem: Double) {
        self.init(sideCount: sideCount, circumradius: apothem / cos(.pi / Double(sideCount)))
    }

    public init(sideCount: Int, sideLength: Double) {
        self.init(sideCount: sideCount, circumradius: sideLength / (2 * sin(.pi / Double(sideCount))))
    }

    public var apothem: Double {
        circumradius * cos(.pi / Double(sideCount))
    }

    public var sideLength: Double {
        circumradius * 2 * sin(.pi / Double(sideCount))
    }

    public var body: Geometry2D {
        Circle(radius: circumradius)
            .usingFacets(count: sideCount)
    }
}
