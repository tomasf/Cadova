import Foundation

/// A `RegularPolygon` represents a regular convex polygon with equal sides and equal angles.
///
/// You can create a `RegularPolygon` by specifying the number of sides, circumradius, apothem, or side length.
/// The struct provides calculated properties to retrieve the apothem and side length based on the initialized parameters.
///
/// # Example
/// Creating a hexagon with a circumradius of 5:
/// ```swift
/// let hexagon = RegularPolygon(sideCount: 6, circumradius: 5)
/// ```
public struct RegularPolygon: Shape2D {
    /// The number of sides in the polygon. Must be at least 3.
    public let sideCount: Int

    /// The distance from the center of the polygon to a vertex.
    public let circumradius: Double

    /// Creates a new `RegularPolygon` instance with the specified number of sides and circumradius.
    ///
    /// - Parameters:
    ///   - sideCount: The number of sides in the polygon. Must be at least 3.
    ///   - circumradius: The distance from the center of the polygon to a vertex. Must be greater than 0.
    public init(sideCount: Int, circumradius: Double) {
        precondition(sideCount >= 3)
        precondition(circumradius > 0)
        self.sideCount = sideCount
        self.circumradius = circumradius
    }

    /// Creates a new `RegularPolygon` instance with the specified number of sides and apothem.
    ///
    /// - Parameters:
    ///   - sideCount: The number of sides in the polygon.
    ///   - apothem: The distance from the center of the polygon to a side.
    public init(sideCount: Int, apothem: Double) {
        self.init(sideCount: sideCount, circumradius: apothem / cos(.pi / Double(sideCount)))
    }

    /// Creates a new `RegularPolygon` instance with the specified number of sides and side length.
    ///
    /// - Parameters:
    ///   - sideCount: The number of sides in the polygon.
    ///   - sideLength: The length of a side of the polygon.
    public init(sideCount: Int, sideLength: Double) {
        self.init(sideCount: sideCount, circumradius: sideLength / (2 * sin(.pi / Double(sideCount))))
    }

    /// The distance from the center of the polygon to a side.
    public var apothem: Double {
        circumradius * cos(.pi / Double(sideCount))
    }

    /// The length of a side of the polygon.
    public var sideLength: Double {
        circumradius * 2 * sin(.pi / Double(sideCount))
    }

    /// The geometry representation of the polygon.
    public var body: any Geometry2D {
        Circle(radius: circumradius)
            .usingFacets(count: sideCount)
    }
}
