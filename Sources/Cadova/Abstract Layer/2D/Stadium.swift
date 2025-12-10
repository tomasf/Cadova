import Foundation

/// A 2D stadium shape composed of a rectangle with semicircular ends.
///
/// A stadium is defined by its overall size (width along the X axis and height along the Y axis),
/// is axis-aligned, and is centered at the origin. The diameter of the semicircular end caps is the
/// smaller of the two dimensions. If both dimensions are equal, the result is a circle.
///
/// Examples:
/// ```swift
/// // A horizontal stadium 40 mm wide and 12 mm tall
/// let pill = Stadium([40, 12])
///
/// // A vertical stadium 12 mm wide and 40 mm tall
/// let tall = Stadium(x: 12, y: 40)
/// ```
///
public struct Stadium: Shape2D {
    /// The overall size of the stadium (width along X, height along Y), measured edge-to-edge.
    public let size: Vector2D

    /// Creates a stadium with the given overall size.
    ///
    /// - Parameter size: The total width (x) and height (y) of the stadium. The smaller component
    ///   determines the diameter of the semicircular end caps; the larger component determines the
    ///   overall length along the major axis.
    public init(_ size: Vector2D) {
        self.size = size
    }

    /// Creates a stadium with the given width and height.
    ///
    /// - Parameters:
    ///   - x: The overall width of the stadium along the X axis.
    ///   - y: The overall height of the stadium along the Y axis.
    ///   The smaller of `x` and `y` determines the diameter of the semicircular end caps.
    public init(x: Double, y: Double) {
        self.init([x, y])
    }

    public var body: any Geometry2D {
        let diameter = min(size.x, size.y)
        let offset = (size - diameter) / 2.0

        Circle(diameter: diameter)
            .distributed(at: offset, -offset)

        Rectangle(
            x: size.x - (size.x > size.y ? diameter : 0),
            y: size.y - (size.y >= size.x ? diameter : 0)
        )
        .aligned(at: .center)
    }
}

extension Stadium: Area, Perimeter {
    /// The area of the stadium.
    public var area: Double {
        let diameter = min(size.x, size.y)
        return Double.pi * (diameter / 2) * (diameter / 2) + (max(size.x, size.y) - diameter) * diameter
    }

    /// The perimeter of the stadium.
    public var perimeter: Double {
        let diameter = min(size.x, size.y)
        return Double.pi * diameter + 2.0 * (max(size.x, size.y) - diameter)
    }
}
