import Foundation

/// A `Rectangle` represents a two-dimensional shape with four straight sides and four right angles.
///
public struct Rectangle: Sendable, Hashable, Codable {
    /// The size of the rectangle represented as a `Vector2D`.
    public let size: Vector2D

    /// Creates a new `Rectangle` instance with the specified size and centering options.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle represented as a `Vector2D`. A component of zero or less results in empty geometry.
    public init(_ size: Vector2D) {
        precondition(size.x.isFinite && size.y.isFinite, "Rectangle dimensions must be finite")
        self.size = size
    }

    /// Creates a new `Rectangle` instance with the specified size.
    ///
    /// - Parameters:
    ///   - x: The size of the rectangle in the X axis. A value of zero or less results in empty geometry.
    ///   - y: The size of the rectangle in the Y axis. A value of zero or less results in empty geometry.
    public init(x: Double, y: Double) {
        self.init(Vector2D(x, y))
    }

    /// Initializes a square.
    /// - Parameters:
    ///   - side: A `Double` value indicating the length of each side of the square. A value of zero or less results in empty geometry.
    public init(_ side: Double) {
        self.init(Vector2D(side, side))
    }
}

extension Rectangle: Geometry2D {
    public var body: any Geometry2D {
        NodeBasedGeometry(.rectangle(size: size))
    }
}

extension Rectangle: Area, Perimeter {
    public var area: Double {
        guard size.x > 0, size.y > 0 else { return 0 }
        return size.x * size.y
    }

    public var perimeter: Double {
        2 * (size.x + size.y)
    }
}
