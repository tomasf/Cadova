import Foundation

/// A `Rectangle` represents a two-dimensional shape with four straight sides and four right angles.
///
/// You can specify the size of the rectangle and control whether it should be centered along certain axes.
///
/// # Example
/// Creating a Rectangle with size and centering options:
/// ```swift
/// let size: Vector2D = [10, 5]
/// let rectangle = Rectangle(size, center: [.x, .y])
/// ```
public struct Rectangle: Geometry2D {
    /// The size of the rectangle represented as a `Vector2D`.
    public let size: Vector2D

    /// The axes on which the rectangle is centered.
    public let center: Axes2D

    /// Creates a new `Rectangle` instance with the specified size and centering options.
    ///
    /// - Parameters:
    ///   - size: The size of the rectangle represented as a `Vector2D`.
    ///   - center: The axes on which the rectangle should be centered. Defaults to an empty array, meaning the rectangle won't be centered on any axis.
    public init(_ size: Vector2D, center: Axes2D = []) {
        self.size = size
        self.center = center
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
    ///   - center: An `Axes3D` option set indicating which axes should be centered around the origin. By omitting or passing an empty set, the square's corner aligns with the origin. Specifying axes centers the square along those axes.
    ///
    /// Example usage:
    /// ```
    /// let square = Rectangle(10, center: .x)
    /// ```
    /// This creates a square of size 10x10, centered along the X axis but not the Y axis.
    public init(_ side: Double, center: Axes2D = []) {
        self.size = [side, side]
        self.center = center
    }

    public func output(in environment: Environment) -> GeometryOutput2D {
        if center.isEmpty {
            .init(
                invocation: .init(name: "square", parameters: ["size": size]),
                boundary: .box(size)
            )
        } else {
            Rectangle(size)
                .translated((size / -2).with(center.inverted, as: 0))
                .output(in: environment)
        }
    }
}
