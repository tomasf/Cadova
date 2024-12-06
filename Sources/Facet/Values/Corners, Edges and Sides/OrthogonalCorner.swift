import Foundation

// A corner of a rectangular shape (Rectangle / Box)
public struct OrthogonalCorner<V: Vector>: Sendable, Hashable {
    let axisDirections: DimensionalValues<AxisDirection, V>

    internal init(axisDirections: DimensionalValues<AxisDirection, V>) {
        self.axisDirections = axisDirections
    }

    public static func max(_ maxAxes: V.Axes) -> Self {
        Self(axisDirections: .init {
            maxAxes.contains($0) ? .max : .min
        })
    }

    internal var maxAxes: V.Axes {
        axisDirections.map { $1 == .max }.axes
    }

    internal func point(boxSize: V) -> V {
        axisDirections.map { boxSize[$0] / 2 * $1.factor }.vector
    }
}
