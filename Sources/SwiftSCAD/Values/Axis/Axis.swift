import Foundation

/// One of the cartesian axes in two dimensions (X or Y)
public enum Axis2D: Int, CaseIterable {
    case x
    case y
}

/// An enumeration representing the three Cartesian axes in a three-dimensional space: X, Y, and Z.
public enum Axis3D: Int, CaseIterable {
    case x
    case y
    case z

    /// The unit vector pointing in the direction of the axis.
    ///
    /// This property returns a `Vector3D` representing the direction of the axis with a magnitude of 1. It is useful for operations that require understanding or manipulating the orientation of geometry in 3D space.
    var direction: Vector3D {
        Vector3D(axis: self, value: 1)
    }

    /// The other two axes that are orthogonal to this axis.
    ///
    /// This property returns an `Axes3D` instance excluding the current axis. It's particularly useful when needing to perform operations or transformations that involve the other two axes, not including the axis represented by the current `Axis3D` instance.
    var otherAxes: Axes3D {
        Axes3D(axis: self).inverted
    }
}

/// A direction along an axis
public enum AxisDirection {
    /// The positive direction along an axis
    case positive
    /// The negative direction along an axis
    case negative
}
