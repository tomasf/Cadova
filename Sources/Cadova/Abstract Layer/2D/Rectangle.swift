import Foundation

/// A `Rectangle` represents a two-dimensional shape with four straight sides and four right angles.
///
public struct Rectangle {
    /// The size of the rectangle represented as a `Vector2D`.
    public let size: Vector2D

    /// Creates a new `Rectangle` instance with the specified size and centering options.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle represented as a `Vector2D`.
    public init(_ size: Vector2D) {
        self.size = size
    }

    /// Creates a new `Rectangle` instance with the specified size.
    ///
    /// - Parameters:
    ///   - x: The size of the rectangle in the X axis
    ///   - y: The size of the rectangle in the Y axis
    public init(x: Double, y: Double) {
        self.init([x, y])
    }

    /// Initializes a square.
    /// - Parameters:
    ///   - side: A `Double` value indicating the length of each side of the square.
    public init(_ side: Double) {
        self.size = [side, side]
    }
}

extension Rectangle: Shape2D {
    public var body: any Geometry2D {
        NodeBasedGeometry(.shape(.rectangle(size: size)))
    }
}

extension Rectangle: Area, Perimeter {
    public var area: Double {
        size.x * size.y
    }

    public var perimeter: Double {
        2 * (size.x + size.y)
    }
}
