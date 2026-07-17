import Foundation

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

public extension Loft {
    /// A result builder for composing loft layers.
    @available(*, deprecated, renamed: "Loft.SectionBuilder")
    typealias LayerBuilder = ArrayBuilder<Layer>

    /// A single cross-section in a lofted shape.
    ///
    /// Each layer defines a 2D shape at a specific Z height. Layers are created using the
    /// `layer(z:interpolation:shape:)` or `layer(zOffset:interpolation:shape:)` functions
    /// within a ``Loft`` builder.
    ///
    @available(*, deprecated, renamed: "Loft.Section")
    struct Layer: Sendable {
        internal enum ZSpecification: Sendable {
            case absolute(Double, upperBound: Double? = nil)
            case offset(Double, upperBound: Double? = nil)
        }

        internal let zSpec: ZSpecification
        internal let transition: LayerTransition?
        internal let geometry: @Sendable () -> any Geometry2D

        internal init(zSpec: ZSpecification, transition: LayerTransition?, geometry: @Sendable @escaping () -> any Geometry2D) {
            self.zSpec = zSpec
            self.transition = transition
            self.geometry = geometry
        }

        internal init(z: Double, transition: LayerTransition?, geometry: @Sendable @escaping () -> any Geometry2D) {
            self.init(zSpec: .absolute(z, upperBound: nil), transition: transition, geometry: geometry)
        }

        internal var z: Double {
            guard case .absolute(let z, _) = zSpec else {
                preconditionFailure("Layer Z has not been resolved — use layer(z:) or layer(zOffset:) inside a Loft builder")
            }
            return z
        }

        internal func resolved(lastZ: inout Double) -> [Layer] {
            switch zSpec {
            case .absolute(let lower, let upper):
                var result = [Layer(z: lower, transition: transition, geometry: geometry)]
                lastZ = lower
                if let upper {
                    result.append(Layer(z: upper, transition: .interpolated(.linear), geometry: geometry))
                    lastZ = upper
                }
                return result
            case .offset(let lower, let upper):
                let baseZ = lastZ
                let lowerZ = baseZ + lower
                var result = [Layer(z: lowerZ, transition: transition, geometry: geometry)]
                lastZ = lowerZ
                if let upper {
                    let upperZ = baseZ + upper
                    result.append(Layer(z: upperZ, transition: .interpolated(.linear), geometry: geometry))
                    lastZ = upperZ
                }
                return result
            }
        }
    }
}

/// Creates a single layer in a lofted shape at the specified Z height.
/// This function is intended to be used inside a `Loft` builder to define each horizontal cross-section.
///
/// - Parameters:
///   - z: The Z height at which to place the 2D shape.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous layer and this one. If `nil`, the `Loft`'s own shaping function is used.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
@available(*, deprecated, renamed: "Section(at:interpolation:shape:)")
public func layer(
    z: Double,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(z: z, transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
}

/// Creates a single layer in a lofted shape at the specified Z height with a specified transition type.
/// This function is intended to be used inside a `Loft` builder to define each horizontal cross-section.
///
/// - Parameters:
///   - z: The Z height at which to place the 2D shape.
///   - transition: The transition type that controls how this layer connects to the previous one.
///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
@available(*, deprecated, renamed: "Section(at:interpolation:shape:)")
public func layer(
    z: Double,
    interpolation transition: LayerTransition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(z: z, transition: transition, geometry: shape)
}

/// Creates a single layer in a lofted shape at a Z height relative to the previous layer.
///
/// The layer is placed at the Z position of the preceding layer plus the given offset.
/// This is useful when building up a loft incrementally, where each layer's height
/// is defined relative to the one before it rather than as an absolute position.
///
/// - Parameters:
///   - zOffset: The Z distance from the previous layer. Must be positive.
///   - shapingFunction: An optional shaping function for the transition from the previous layer.
///                      If `nil`, the `Loft`'s own shaping function is used.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with an absolute distance instead")
public func layer(
    zOffset: Double,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .offset(zOffset), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
}

/// Creates a single layer in a lofted shape at a Z height relative to the previous layer,
/// with a specified transition type.
///
/// - Parameters:
///   - zOffset: The Z distance from the previous layer. Must be positive.
///   - transition: The transition type that controls how this layer connects to the previous one.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with an absolute distance instead")
public func layer(
    zOffset: Double,
    interpolation transition: LayerTransition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .offset(zOffset), transition: transition, geometry: shape)
}

/// Creates two layers spanning an offset range using the same 2D shape.
///
/// This convenience overload generates a pair of `Loft.Layer` entries from a single shape:
/// one at `previous + range.lowerBound` and one at `previous + range.upperBound`, both using
/// the same shape. This is useful when you want a straight shape across the specified interval,
/// defined relative to the previous layer rather than at an absolute Z position.
///
/// - Parameters:
///   - range: The Z offset range relative to the previous layer.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous layer and the lower bound of this range. If `nil`, the `Loft`'s shaping
///                      function is used for the first layer.
///   - shape: A builder that returns the 2D geometry to use for both layers.
/// - Returns: Two `Loft.Layer` values, one at the lower bound offset and one at the upper bound offset.
///
@available(*, deprecated, message: "Use Section(atRelative:interpolation:shape:) with a range instead")
public func layer(
    zOffset range: Range<Double>,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .offset(range.lowerBound, upperBound: range.upperBound), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
}

/// Creates two layers spanning an offset range using the same 2D shape with a specified transition type.
///
/// - Parameters:
///   - range: The Z offset range relative to the previous layer.
///   - transition: The transition type that controls how this layer connects to the previous one.
///   - shape: A builder that returns the 2D geometry to use for both layers.
///
@available(*, deprecated, message: "Use Section(atRelative:interpolation:shape:) with a range instead")
public func layer(
    zOffset range: Range<Double>,
    interpolation transition: LayerTransition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .offset(range.lowerBound, upperBound: range.upperBound), transition: transition, geometry: shape)
}

/// Creates two layers spanning a Z range using the same 2D shape.
///
/// This convenience overload generates a pair of `Loft.Layer` entries from a single shape:
/// one at `range.lowerBound` using the provided `shapingFunction` (or the `Loft` default if `nil`),
/// and one at `range.upperBound` using a linear shaping function. This is useful when you want a
/// straight shape across the specified interval.
///
/// - Parameters:
///   - range: The Z range defining the lower and upper bounds where the shape will be placed.
///   - shapingFunction: An optional shaping function that controls how the transition progresses between
///                      the previous layer and the lower bound of this range. If `nil`, the `Loft`'s shaping
///                      function is used for the first layer.
///   - shape: A builder that returns the 2D geometry to use for both layers.
/// - Returns: Two `Loft.Layer` values, one at the lower bound and one at the upper bound.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with a range instead")
public func layer(
    z range: Range<Double>,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .absolute(range.lowerBound, upperBound: range.upperBound), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
}

/// Creates two layers spanning a Z range using the same 2D shape with a specified transition type.
///
/// This convenience overload generates a pair of `Loft.Layer` entries from a single shape:
/// one at `range.lowerBound` using the provided transition, and one at `range.upperBound` using
/// a linear interpolation. This is useful when you want a straight shape across the specified interval.
///
/// - Parameters:
///   - range: The Z range defining the lower and upper bounds where the shape will be placed.
///   - transition: The transition type that controls how this layer connects to the previous one.
///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
@available(*, deprecated, message: "Use Section(at:interpolation:shape:) with a range instead")
public func layer(
    z range: Range<Double>,
    interpolation transition: LayerTransition,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(zSpec: .absolute(range.lowerBound, upperBound: range.upperBound), transition: transition, geometry: shape)
}

public extension Loft {
    /// Creates a lofted 3D geometry by interpolating between a series of 2D cross-sections using a resampling-based approach.
    ///
    /// Resampling allows precise matching of complex shapes, including those with holes. All layers must have compatible
    /// topology: each layer must have the same number of top-level shapes, and each shape must have the same number of
    /// holes (if any), and so on.
    ///
    /// - Parameters:
    ///   - interpolation: The shaping function to use between layers. Defaults to `.linear`. Individual layers can
    ///     override this by specifying their own shaping function in `layer(...)`.
    ///   - layers: A builder that returns the list of layers. Each layer must have a Z position and a 2D shape.
    ///
    @available(*, deprecated, renamed: "init(interpolation:pointing:toward:sections:)")
    init(interpolation: ShapingFunction = .linear, @LayerBuilder layers: () -> [Layer]) {
        var lastZ = 0.0
        var resolvedLayers: [Layer] = []
        for layer in layers() {
            resolvedLayers.append(contentsOf: layer.resolved(lastZ: &lastZ))
        }
        let sortedLayers = resolvedLayers.sorted(by: { $0.z < $1.z })
        precondition(sortedLayers.count >= 2, "Loft requires at least two layers")

        let sections = sortedLayers.map { Section(distance: $0.z, transition: $0.transition, geometry: $0.geometry) }
        let (path, shiftedSections) = Loft.implicitPath(for: sections)
        self.init(path: path, sections: shiftedSections, shapingFunction: interpolation, reference: .negativeY, target: .direction(.negativeY))
    }
}
