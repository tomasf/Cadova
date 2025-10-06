import Foundation

/// A 2D capsule shape composed of a rectangle with semicircular ends.
///
/// A capsule is defined by its overall size (width along the X axis and height along the Y axis),
/// is axis-aligned, and is centered at the origin. The diameter of the semicircular end caps is the
/// smaller of the two dimensions. If both dimensions are equal, the result is a circle.
///
/// Examples:
/// ```swift
/// // A horizontal capsule 40 mm wide and 12 mm tall
/// let pill = Capsule([40, 12])
///
/// // A vertical capsule 12 mm wide and 40 mm tall
/// let tall = Capsule(x: 12, y: 40)
/// ```
///
public struct Capsule: Shape2D {
    /// The overall size of the capsule (width along X, height along Y), measured edge-to-edge.
    public let size: Vector2D

    /// Creates a capsule with the given overall size.
    ///
    /// - Parameter size: The total width (x) and height (y) of the capsule. The smaller component
    ///   determines the diameter of the semicircular end caps; the larger component determines the
    ///   overall length along the major axis.
    public init(_ size: Vector2D) {
        self.size = size
    }

    /// Creates a capsule with the given width and height.
    ///
    /// - Parameters:
    ///   - x: The overall width of the capsule along the X axis.
    ///   - y: The overall height of the capsule along the Y axis.
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

extension Capsule: Area, Perimeter {
    public var area: Double {
        let diameter = min(size.x, size.y)
        return Double.pi * (diameter / 2) * (diameter / 2) + (max(size.x, size.y) - diameter) * diameter
    }

    public var perimeter: Double {
        let diameter = min(size.x, size.y)
        return Double.pi * diameter + 2.0 * (max(size.x, size.y) - diameter)
    }
}
