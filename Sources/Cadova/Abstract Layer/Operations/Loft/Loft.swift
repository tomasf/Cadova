import Foundation

/// A 3D shape constructed by interpolating between a series of 2D cross-sections layered at different Z positions.
///
/// Lofting is a modeling technique that creates a smooth transition between multiple 2D shapes across different
/// heights. Each 2D shape forms a horizontal cross-section of the final 3D shape, and the space between these layers
/// is filled in by connecting the layers using a resampling-based interpolation method.
///
/// The loft uses a resampled interpolation strategy: each shape is resampled to have matching vertex counts across
/// layers. This allows precise matching of complex shapes, including those with holes. All layers must have compatible
/// topology; that is, each layer must have the same number of top-level shapes, and each shape must have the same
/// number of holes (if any), and so on.
///
/// The `ShapingFunction` determines how intermediate layers are distributed and how the transition between each pair
/// of cross-sections progresses. By default, the interpolation is linear, meaning each intermediate layer is evenly
/// spaced in both height and shape between the source and target layers. By supplying a different shaping function,
/// you can control the interpolation rate—such as using "ease in", "ease out", or a custom curve. This can be used to
/// create organic bulges, tapering, or other stylized transitions between layers. Individual layers can override this
/// function by specifying their own shaping function in the corresponding `layer(...)` call.
///
/// Each layer is specified using a Z height and a 2D shape (any Geometry2D-conforming type). At least two layers
/// must be provided.
///
/// - Example:
///   ```swift
///   Loft {
///       layer(at: 0) {
///           Circle(radius: 10)
///       }
///       layer(at: 20) {
///           Rectangle(20)
///               .aligned(at: .center)
///       }
///   }
///   ```
///   This creates a lofted 3D shape by interpolating between a circle at the base and a square at the top.
///
/// - Example with three layers. Each layer has one hole each, fulfilling the requirement for compatible topology.
///   ```swift
///   Loft {
///       layer(at: 0) {
///           Circle(diameter: 20)
///               .subtracting {
///                   Circle(diameter: 12)
///               }
///       }
///       layer(at: 30) {
///           Rectangle(x: 25, y: 6)
///               .aligned(at: .center)
///               .repeated(in: 0°..<180°, count: 2)
///               .subtracting {
///                   RegularPolygon(sideCount: 8, circumradius: 2)
///               }
///       }
///       layer(at: 35) {
///           Circle(diameter: 12)
///               .subtracting {
///                   Circle(diameter: 10)
///               }
///       }
///   }
///   ```
///
public struct Loft: Geometry {
    public typealias D = D3

    internal let layers: [Layer]
    internal let shapingFunction: ShapingFunction

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
    public init(interpolation: ShapingFunction = .linear, @LayerBuilder layers: () -> [Layer]) {
        self.shapingFunction = interpolation
        self.layers = layers().sorted(by: { $0.z < $1.z })
        precondition(self.layers.count >= 2, "Loft requires at least two layers")
    }

    /// A result builder for composing loft layers.
    public typealias LayerBuilder = ArrayBuilder<Layer>

    /// A single cross-section in a lofted shape.
    ///
    /// Each layer defines a 2D shape at a specific Z height. Layers are created using the
    /// ``layer(z:interpolation:shape:)`` function within a ``Loft`` builder.
    ///
    public struct Layer: Sendable {
        internal let z: Double
        internal let shapingFunction: ShapingFunction?
        internal let geometry: @Sendable () -> any Geometry2D
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
public func layer(
    z: Double,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> Loft.Layer {
    Loft.Layer(z: z, shapingFunction: shapingFunction, geometry: shape)
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
public func layer(
    z range: Range<Double>,
    interpolation shapingFunction: ShapingFunction? = nil,
    @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
) -> [Loft.Layer] {
    [
        Loft.Layer(z: range.lowerBound, shapingFunction: shapingFunction, geometry: shape),
        Loft.Layer(z: range.upperBound, shapingFunction: .linear, geometry: shape)
    ]
}

public extension Geometry2D {
    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two layers.
    ///
    /// The loft uses a resampling-based interpolation strategy: each shape is resampled to have matching vertex counts
    /// across layers. All layers must have compatible topology.
    ///
    /// - Parameters:
    ///   - shapingFunction: The shaping function applied to the transition. Defaults to `.linear`.
    ///   - height: The vertical distance between the two layers.
    ///   - other: A builder that returns the 2D shape to use for the second layer, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D layers.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///   This creates a lofted shape from a circle at the base to a square at the top.
    ///
    /// - SeeAlso: `Loft`
    func lofted(
        shapingFunction: ShapingFunction = .linear,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft(interpolation: shapingFunction) {
            layer(z: 0) { self }
            layer(z: height, shape: other)
        }
    }
}
