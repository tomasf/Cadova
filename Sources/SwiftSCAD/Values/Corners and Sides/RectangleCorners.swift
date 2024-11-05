import Foundation

/// A structure that defines the corners of a rectangle using an option set.
///
/// `RectangleCorners` allows for specifying and manipulating individual corners or groups of corners of a rectangle.
/// It is used for operations that involve corner-specific modifications, such as rounding corners.

public struct RectangleCorners: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let bottomLeft = Self(rawValue: 1 << 0)
    public static let topLeft = Self(rawValue: 1 << 1)
    public static let topRight = Self(rawValue: 1 << 2)
    public static let bottomRight = Self(rawValue: 1 << 3)

    /// A set containing all corners of the rectangle.
    public static let all: RectangleCorners = [.bottomLeft, .bottomRight, .topRight, .topLeft]

    /// A set containing none of the corners.
    public static let none: RectangleCorners = []

    public static let top: RectangleCorners = [.topRight, .topLeft]
    public static let bottom: RectangleCorners = [.bottomLeft, .bottomRight]
    public static let left: RectangleCorners = [.bottomLeft, .topLeft]
    public static let right: RectangleCorners = [.bottomRight, .topRight]

    /// Returns a new set of rectangle corners with the specified corners inverted.
    ///
    /// This operator returns a set containing all corners that are not in the original set.
    ///
    /// - Parameter corners: The set of corners to invert.
    /// - Returns: A new set of rectangle corners with the specified corners inverted.
    ///
    /// Example usage:
    /// ```swift
    /// let corners: RectangleCorners = [.topLeft, .bottomRight]
    /// let notTopLeftOrBottomRight = ~corners
    /// // notTopLeftOrBottomRight contains [.bottomLeft, .topRight]
    /// ```

    public static prefix func ~(_ corners: RectangleCorners) -> RectangleCorners {
        .all.subtracting(corners)
    }
}
