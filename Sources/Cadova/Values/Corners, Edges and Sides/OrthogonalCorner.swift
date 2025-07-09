import Foundation

// A corner of a rectangular shape (Rectangle / Box)
public struct OrthogonalCorner<D: Dimensionality>: Sendable, Hashable, Comparable {
    let axisDirections: DimensionalValues<LinearDirection, D>

    internal init(axisDirections: DimensionalValues<LinearDirection, D>) {
        self.axisDirections = axisDirections
    }

    public static func max(_ maxAxes: D.Axes) -> Self {
        Self(axisDirections: .init {
            maxAxes.contains($0) ? .max : .min
        })
    }

    internal var maxAxes: D.Axes {
        axisDirections.map { $1 == .max }.axes
    }

    internal func point(boxSize: D.Vector) -> D.Vector {
        axisDirections.map { boxSize[$0] / 2 * $1.factor }.vector
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.axisDirections < rhs.axisDirections
    }
}
