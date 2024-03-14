import Foundation

/// One of the cartesian axes in two dimensions (X or Y)
public enum Axis2D: Int, CaseIterable {
    case x
    case y
}

/// One of the cartesian axes in three dimensions (X, Y or Z)
public enum Axis3D: Int, CaseIterable {
    case x
    case y
    case z

    var direction: Vector3D {
        Vector3D(axis: self, value: 1)
    }
}

/// A direction along an axis
public enum AxisDirection {
    /// The positive direction along an axis
    case positive
    /// The negative direction along an axis
    case negative
}
