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

public extension ParametricCurve {
    @available(*, deprecated, renamed: "readingPoints(_:)")
    func readPoints<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([V]) -> D.Geometry
    ) -> D.Geometry {
        readingPoints(reader)
    }

    @available(*, deprecated, renamed: "readingSamples(_:)")
    func readSamples<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([CurveSample<V>]) -> D.Geometry
    ) -> D.Geometry {
        readingSamples(reader)
    }

    @available(*, deprecated, renamed: "readingSamples(at:_:)")
    func readSamples<D: Dimensionality>(
        at interval: CurveSampleInterval,
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([CurveSample<V>]) -> D.Geometry
    ) -> D.Geometry {
        readingSamples(at: interval, reader)
    }
}

public extension Polygon {
    @available(*, deprecated, renamed: "readingMetrics(_:)")
    func readMetrics<D: Dimensionality>(@GeometryBuilder<D> _ reader: @Sendable @escaping (Metrics) -> D.Geometry) -> D.Geometry {
        readingMetrics(reader)
    }
}
