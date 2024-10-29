import Foundation

fileprivate extension BoundingBox {
    func partialBox(from: Double?, to: Double?, in axis: V.Axes.Axis) -> BoundingBox {
        .init(
            minimum: minimum.with(axis, as: from ?? minimum[axis] - 1),
            maximum: maximum.with(axis, as: to ?? maximum[axis] + 1)
        )
    }

    static var universe: Self {
        .init(minimum: .init(-1000), maximum: .init(1000))
    }
}

internal extension BoundingBox2D {
    var mask: any Geometry2D {
        Rectangle(size).translated(minimum)
    }
}

internal extension BoundingBox3D {
    var mask: any Geometry3D {
        Box(size).translated(minimum)
    }
}

public extension Geometry2D {
    /// Returns a geometry sliced within the specified x and y ranges.
    ///
    /// - Parameters:
    ///   - x: A range expression for the x-axis. If `nil`, the geometry is not restricted along the x-axis.
    ///   - y: A range expression for the y-axis. If `nil`, the geometry is not restricted along the y-axis.
    /// - Returns: A new geometry representing the original geometry constrained within the specified ranges.
    ///
    func within(
        x: (any RangeExpression<Double>)? = nil,
        y: (any RangeExpression<Double>)? = nil
    ) -> any Geometry2D {
        measuringBounds { _, measuredBox in
            var box = measuredBox ?? .universe
            box = box.partialBox(from: x?.min, to: x?.max, in: .x)
            box = box.partialBox(from: y?.min, to: y?.max, in: .y)
            self.intersecting { box.mask }
        }
    }
}

public extension Geometry3D {
    /// Returns a geometry sliced within the specified x, y, and z ranges.
    ///
    /// - Parameters:
    ///   - x: A range expression for the x-axis. If `nil`, the geometry is not restricted along the x-axis.
    ///   - y: A range expression for the y-axis. If `nil`, the geometry is not restricted along the y-axis.
    ///   - z: A range expression for the z-axis. If `nil`, the geometry is not restricted along the z-axis.
    /// - Returns: A new geometry representing the original geometry constrained within the specified ranges.
    ///
    func within(
        x: (any RangeExpression<Double>)? = nil,
        y: (any RangeExpression<Double>)? = nil,
        z: (any RangeExpression<Double>)? = nil
    ) -> any Geometry3D {
        measuringBounds { _, measuredBox in
            var box = measuredBox ?? .universe
            box = box.partialBox(from: x?.min, to: x?.max, in: .x)
            box = box.partialBox(from: y?.min, to: y?.max, in: .y)
            box = box.partialBox(from: z?.min, to: z?.max, in: .z)
            self.intersecting { box.mask }
        }
    }
}
