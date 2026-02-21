import Foundation

/// Specifies how a loft layer transitions from the previous layer.
///
/// This enum provides control over the geometric operation used to connect two adjacent
/// layers in a loft. By default, layers are connected via shape interpolation, but you
/// can also specify a convex hull connection for certain segments.
///
public enum LayerTransition: Hashable, Sendable, Codable {
    /// Interpolates between the previous layer's shape and this layer's shape using
    /// the specified shaping function.
    ///
    /// The shaping function controls the rate of interpolation. For example, `.linear`
    /// produces evenly spaced intermediate cross-sections, while `.easeIn` or `.easeOut`
    /// can create more organic transitions.
    ///
    case interpolated(ShapingFunction)

    /// Connects the previous layer to this layer using a 3D convex hull.
    ///
    /// Instead of interpolating intermediate cross-sections, this creates the smallest
    /// convex shape that contains both layers. This is useful for creating tapered or
    /// faceted transitions between shapes, especially when both shapes are convex.
    ///
    /// - Note: The convex hull operation ignores holes in the shapes. The result will
    ///   be a solid convex polyhedron connecting the outer boundaries of both layers.
    ///
    case convexHull
}

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
        var lastZ = 0.0
        var resolved: [Layer] = []
        for layer in layers() {
            resolved.append(contentsOf: layer.resolved(lastZ: &lastZ))
        }
        self.layers = resolved.sorted(by: { $0.z < $1.z })
        precondition(self.layers.count >= 2, "Loft requires at least two layers")
    }
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

    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset,
    /// using the specified layer transition.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two layers.
    ///
    /// - Parameters:
    ///   - transition: The transition type that controls how the second layer connects to the first.
    ///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
    ///   - height: The vertical distance between the two layers.
    ///   - other: A builder that returns the 2D shape to use for the second layer, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D layers.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(transition: .convexHull, height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///
    /// - SeeAlso: `Loft`, `LayerTransition`
    func lofted(
        transition: LayerTransition,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft {
            layer(z: 0) { self }
            layer(z: height, interpolation: transition, shape: other)
        }
    }
}
