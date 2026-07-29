import Foundation

/// Deprecated. Use ``Geometry`` directly.
@available(*, deprecated, renamed: "Geometry", message: "Conform to Geometry directly.")
public typealias Shape = Geometry

/// Deprecated. Use ``Geometry2D`` directly.
@available(*, deprecated, renamed: "Geometry2D", message: "Conform to Geometry2D directly.")
public protocol Shape2D: Geometry where D == D2 {
    @GeometryBuilder2D var body: any Geometry2D { get }
}

/// Deprecated. Use ``Geometry3D`` directly.
@available(*, deprecated, renamed: "Geometry3D", message: "Conform to Geometry3D directly.")
public protocol Shape3D: Geometry where D == D3 {
    @GeometryBuilder3D var body: any Geometry3D { get }
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

@available(*, deprecated, renamed: "Loft.Transition")
public typealias LayerTransition = Loft.Transition

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

// `Loft.Layer` itself is gone — these functions now build `Section` values directly, so old
// `Loft(interpolation:) { layer(z: 0) { ... } }` call sites resolve straight to the current
// `Section`-based `Loft.init`, with no separate deprecated initializer needed to bridge them.

/// Creates a single cross-section in a lofted shape at the specified Z height.
/// This function is intended to be used inside a `Loft` builder to define each horizontal cross-section.
///
/// - Parameters:
///   - z: The Z height at which to place the 2D shape.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous section and this one. If `nil`, the `Loft`'s own shaping function is used.
///   - shape: A builder that returns the 2D geometry to use for this section.
///
@available(*, deprecated, renamed: "Section(at:interpolation:shape:)")
public func layer(
    z: Double,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(at: z, interpolation: shapingFunction, shape: shape)
}

/// Creates a single cross-section in a lofted shape at the specified Z height with a specified transition type.
/// This function is intended to be used inside a `Loft` builder to define each horizontal cross-section.
///
/// - Parameters:
///   - z: The Z height at which to place the 2D shape.
///   - transition: The transition type that controls how this section connects to the previous one.
///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
///   - shape: A builder that returns the 2D geometry to use for this section.
///
@available(*, deprecated, renamed: "Section(at:interpolation:shape:)")
public func layer(
    z: Double,
    interpolation transition: Loft.Transition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(at: z, interpolation: transition, shape: shape)
}

/// Creates a single cross-section in a lofted shape at a Z height relative to the previous section.
///
/// The section is placed at the Z position of the preceding section plus the given offset.
/// This is useful when building up a loft incrementally, where each section's height
/// is defined relative to the one before it rather than as an absolute position.
///
/// - Parameters:
///   - zOffset: The Z distance from the previous section. Must be positive.
///   - shapingFunction: An optional shaping function for the transition from the previous section.
///                      If `nil`, the `Loft`'s own shaping function is used.
///   - shape: A builder that returns the 2D geometry to use for this section.
///
@available(*, deprecated, renamed: "Section(atRelative:interpolation:shape:)")
public func layer(
    zOffset: Double,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(atRelative: zOffset, interpolation: shapingFunction, shape: shape)
}

/// Creates a single cross-section in a lofted shape at a Z height relative to the previous section,
/// with a specified transition type.
///
/// - Parameters:
///   - zOffset: The Z distance from the previous section. Must be positive.
///   - transition: The transition type that controls how this section connects to the previous one.
///   - shape: A builder that returns the 2D geometry to use for this section.
///
@available(*, deprecated, renamed: "Section(atRelative:interpolation:shape:)")
public func layer(
    zOffset: Double,
    interpolation transition: Loft.Transition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(atRelative: zOffset, interpolation: transition, shape: shape)
}

/// Creates two cross-sections spanning an offset range using the same 2D shape.
///
/// This convenience overload generates a pair of `Section` entries from a single shape:
/// one at `previous + range.lowerBound` and one at `previous + range.upperBound`, both using
/// the same shape. This is useful when you want a straight shape across the specified interval,
/// defined relative to the previous section rather than at an absolute Z position.
///
/// - Parameters:
///   - range: The Z offset range relative to the previous section.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous section and the lower bound of this range. If `nil`, the `Loft`'s shaping
///                      function is used for the first section.
///   - shape: A builder that returns the 2D geometry to use for both sections.
///
@available(*, deprecated, message: "Use Section(atRelative:interpolation:shape:) with a range instead")
public func layer(
    zOffset range: Range<Double>,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(atRelative: range, interpolation: shapingFunction, shape: shape)
}

/// Creates two cross-sections spanning an offset range using the same 2D shape with a specified transition type.
///
/// - Parameters:
///   - range: The Z offset range relative to the previous section.
///   - transition: The transition type that controls how this section connects to the previous one.
///   - shape: A builder that returns the 2D geometry to use for both sections.
///
@available(*, deprecated, message: "Use Section(atRelative:interpolation:shape:) with a range instead")
public func layer(
    zOffset range: Range<Double>,
    interpolation transition: Loft.Transition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(atRelative: range, interpolation: transition, shape: shape)
}

/// Creates two cross-sections spanning a Z range using the same 2D shape.
///
/// This convenience overload generates a pair of `Section` entries from a single shape:
/// one at `range.lowerBound` using the provided `shapingFunction` (or the `Loft` default if `nil`),
/// and one at `range.upperBound` using a linear shaping function. This is useful when you want a
/// straight shape across the specified interval.
///
/// - Parameters:
///   - range: The Z range defining the lower and upper bounds where the shape will be placed.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous section and the lower bound of this range. If `nil`, the `Loft`'s shaping
///                      function is used for the first section.
///   - shape: A builder that returns the 2D geometry to use for both sections.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with a range instead")
public func layer(
    z range: Range<Double>,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(at: range, interpolation: shapingFunction, shape: shape)
}

/// Creates two cross-sections spanning a Z range using the same 2D shape with a specified transition type.
///
/// This convenience overload generates a pair of `Section` entries from a single shape:
/// one at `range.lowerBound` using the provided transition, and one at `range.upperBound` using
/// a linear interpolation. This is useful when you want a straight shape across the specified interval.
///
/// - Parameters:
///   - range: The Z range defining the lower and upper bounds where the shape will be placed.
///   - transition: The transition type that controls how this section connects to the previous one.
///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
///   - shape: A builder that returns the 2D geometry to use for this section.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with a range instead")
public func layer(
    z range: Range<Double>,
    interpolation transition: Loft.Transition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Section {
    Loft.Section(at: range, interpolation: transition, shape: shape)
}
