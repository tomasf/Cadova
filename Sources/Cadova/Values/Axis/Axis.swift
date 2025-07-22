import Foundation

public protocol Axis: Equatable, Hashable, CaseIterable, Sendable, Codable {
    associatedtype D: Dimensionality where D.Axis == Self
    var index: Int { get }
}

public extension Axis {
    /// The unit vector pointing along the axis, in either the positive or negative direction.
    func direction(_ direction: LinearDirection) -> D.Direction {
        .init(self, direction)
    }
}

/// One of the cartesian axes in two dimensions (X or Y)
public enum Axis2D: Int, Axis {
    public typealias D = D2

    case x
    case y

    public var index: Int { rawValue }
    public var otherAxis: Self { self == .x ? .y : .x }
}

/// An enumeration representing the three Cartesian axes in a three-dimensional space: X, Y, and Z.
public enum Axis3D: Int, Axis {
    public typealias D = D3

    case x
    case y
    case z

    public init(_ axis: Axis2D) {
        self.init(rawValue: axis.rawValue)!
    }

    /// The other two axes that are orthogonal to this axis.
    ///
    /// This property returns an `Axes3D` instance excluding the current axis. It's particularly useful when needing to
    /// perform operations or transformations that involve the other two axes, not including the axis represented by
    /// the current `Axis3D` instance.
    /// 
    var otherAxes: Axes3D {
        Axes3D([self]).inverted
    }

    public var index: Int { rawValue }
}
