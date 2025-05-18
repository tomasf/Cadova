import Foundation

/// Represents an axis in a given dimensional space along with a linear direction on that axis.
///
/// This type is useful for identifying oriented directions, such as the sides of a box (e.g., +X, -Z).
public struct DirectionalAxis<D: Dimensionality>: Sendable {

    /// The axis this direction is aligned with.
    public let axis: D.Axis

    /// The direction along the axis (positive or negative).
    public let axisDirection: LinearDirection

    /// Creates a new directional axis.
    ///
    /// - Parameters:
    ///   - axis: The axis along which the direction lies.
    ///   - direction: The direction along the axis.
    public init(axis: D.Axis, towards direction: LinearDirection) {
        self.axis = axis
        self.axisDirection = direction
    }

    /// Returns the full directional vector represented by this axis and direction.
    public var direction: D.Direction {
        axis.direction(axisDirection)
    }
}

public extension DirectionalAxis where D == D2 {
    /// The negative X direction (left side).
    static let minX = Self(axis: .x, towards: .negative)

    /// The positive X direction (right side).
    static let maxX = Self(axis: .x, towards: .positive)

    /// The negative Y direction (bottom side).
    static let minY = Self(axis: .y, towards: .negative)

    /// The positive Y direction (top side).
    static let maxY = Self(axis: .y, towards: .positive)

    /// Synonym for `minX`, representing the left side.
    static let left = minX

    /// Synonym for `maxX`, representing the right side.
    static let right = maxX

    /// Synonym for `minY`, representing the bottom side.
    static let bottom = minY

    /// Synonym for `maxY`, representing the top side.
    static let top = maxY
}

public extension DirectionalAxis where D == D3 {
    /// The negative X direction (left side).
    static let minX = Self(axis: .x, towards: .negative)

    /// The positive X direction (right side).
    static let maxX = Self(axis: .x, towards: .positive)

    /// The negative Y direction (front side).
    static let minY = Self(axis: .y, towards: .negative)

    /// The positive Y direction (back side).
    static let maxY = Self(axis: .y, towards: .positive)

    /// The negative Z direction (bottom side).
    static let minZ = Self(axis: .z, towards: .negative)

    /// The positive Z direction (top side).
    static let maxZ = Self(axis: .z, towards: .positive)

    /// Synonym for `minX`, representing the left side.
    static let left = minX

    /// Synonym for `maxX`, representing the right side.
    static let right = maxX

    /// Synonym for `minY`, representing the front side.
    static let front = minY

    /// Synonym for `maxY`, representing the back side.
    static let back = maxY

    /// Synonym for `minZ`, representing the bottom side.
    static let bottom = minZ

    /// Synonym for `maxZ`, representing the top side.
    static let top = maxZ
}

/// Convenience alias for referring to the sides of a 2D rectangle using directional axes.
public extension Rectangle {
    /// A type representing one of the four orthogonal sides of a 2D rectangle.
    typealias Side = DirectionalAxis<D2>
}

/// Convenience alias for referring to the sides of a 3D box using directional axes.
public extension Box {
    /// A type representing one of the six orthogonal sides of a 3D box.
    typealias Side = DirectionalAxis<D3>
}
