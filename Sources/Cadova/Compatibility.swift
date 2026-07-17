import Foundation

public extension Geometry2D {
    @available(*, deprecated, renamed: "fillingHoles")
    func filled() -> any Geometry2D {
        fillingHoles()
    }
}

public extension Geometry {
    @available(*, deprecated, renamed: "resized(_:in:to:alignment:)")
    @GeometryBuilder<D>
    func resizing(
        _ axis: D.Axis,
        in range: ClosedRange<Double>,
        to newLength: Double,
        alignment: AxisAlignment = .min
    ) -> D.Geometry {
        resized(axis, in: range, to: newLength, alignment: alignment)
    }
}

public extension Geometry3D {
    @available(*, deprecated, renamed: "extended(at:by:alignment:)")
    func extending(at plane: Plane, by amount: Double, alignment: AxisAlignment = .min) -> any Geometry3D {
        extended(at: plane, by: amount, alignment: alignment)
    }

    @available(*, deprecated, renamed: "extended(_:by:at:alignment:)")
    func extending(_ axis: Axis3D, by amount: Double, at position: Double, alignment: AxisAlignment = .min) -> any Geometry3D {
        extended(axis, by: amount, at: position, alignment: alignment)
    }
}
