import Foundation

public protocol Axis: Equatable, CaseIterable, Sendable {
    var index: Int { get }
}

/// One of the cartesian axes in two dimensions (X or Y)
public enum Axis2D: Int, Axis {
    case x
    case y

    public var index: Int { rawValue }
}

/// An enumeration representing the three Cartesian axes in a three-dimensional space: X, Y, and Z.
public enum Axis3D: Int, Axis {
    case x
    case y
    case z

    public init(_ axis: Axis2D) {
        switch axis {
        case .x: self = .x
        case .y: self = .y
        }
    }

    /// The unit vector pointing along the axis, in either the positive or negative direction.
    func directionVector(_ direction: AxisDirection) -> Vector3D {
        Vector3D(self, value: direction.factor)
    }

    /// The other two axes that are orthogonal to this axis.
    ///
    /// This property returns an `Axes3D` instance excluding the current axis. It's particularly useful when needing to perform operations or transformations that involve the other two axes, not including the axis represented by the current `Axis3D` instance.
    var otherAxes: Axes3D {
        Axes3D(axis: self).inverted
    }

    public var index: Int { rawValue }
}
