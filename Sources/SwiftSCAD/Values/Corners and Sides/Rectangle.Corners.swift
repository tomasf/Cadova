import Foundation

/// A structure that defines the corners of a rectangle using an option set.
///
/// `Rectangle.Corners` allows for specifying and manipulating individual corners or groups of corners of a rectangle.
/// It is used for operations that involve corner-specific modifications, such as rounding.

extension Rectangle {
    public struct Corners: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let minXminY = Self(rawValue: 1 << 0)
        public static let minXmaxY = Self(rawValue: 1 << 1)
        public static let maxXmaxY = Self(rawValue: 1 << 2)
        public static let maxXminY = Self(rawValue: 1 << 3)

        public static let bottomLeft = minXminY
        public static let topLeft = minXmaxY
        public static let topRight = maxXmaxY
        public static let bottomRight = maxXminY

        /// A set containing all corners of the rectangle.
        public static let all: Self = [.minXminY, .minXmaxY, .maxXmaxY, .maxXminY]

        /// A set containing none of the corners.
        public static let none: Self = []

        public static let minX: Self = [.minXminY, .minXmaxY]
        public static let maxX: Self = [.maxXminY, .maxXmaxY]
        public static let minY: Self = [.minXminY, .maxXminY]
        public static let maxY: Self = [.minXmaxY, .maxXmaxY]

        public static let top: Self = maxY
        public static let bottom: Self = minY
        public static let left: Self = minX
        public static let right: Self = maxX

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

        internal func cornerCountAffecting(_ axis: Axis2D) -> Int {
            switch axis {
            case .x: (isDisjoint(with: Self.minX) ? 0 : 1) + (isDisjoint(with: Self.maxX) ? 0 : 1)
            case .y: (isDisjoint(with: Self.minY) ? 0 : 1) + (isDisjoint(with: Self.maxY) ? 0 : 1)
            }
        }
    }
}
