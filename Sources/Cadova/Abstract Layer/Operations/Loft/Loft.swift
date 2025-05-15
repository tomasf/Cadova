import Foundation

/// A 3D shape constructed by interpolating between a series of 2D cross-sections layered at different Z positions.
///
/// Lofting is a modeling technique that creates a smooth transition between multiple 2D shapes across different heights.
/// Each 2D shape forms a horizontal cross-section of the final 3D shape, and the space between these layers is filled in by connecting
/// the layers using a specific interpolation method.
///
/// Each layer is specified using a Z height and a 2D shape (any Geometry2D-conforming type). At least two layers must be provided.
///
/// - Example:
///   ```swift
///   Loft {
///       layer(z: 0) {
///           Circle(radius: 10)
///       }
///       layer(z: 20) {
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
///       layer(z: 0) {
///           Circle(diameter: 20)
///               .subtracting {
///                   Circle(diameter: 12)
///               }
///       }
///       layer(z: 30) {
///           Rectangle(x: 25, y: 6)
///               .aligned(at: .center)
///               .repeated(in: 0°..<180°, count: 2)
///               .subtracting {
///                   RegularPolygon(sideCount: 8, circumradius: 2)
///               }
///       }
///       layer(z: 35) {
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
    internal let interpolation: LayerInterpolation

    /// Creates a lofted 3D geometry by interpolating between a series of 2D cross-sections.
    ///
    /// - Parameters:
    ///   - method: The interpolation method to use between layers. Defaults to `.automatic`, which selects `.convexHull` if all
    ///     layers are convex, otherwise `.resampled`.
    ///   - layers: A builder that returns the list of layers. Each layer must have a Z position and a 2D shape.
    ///
    /// When using the `.resampled` method, all layers must have compatible topology: each layer must have the same number of
    /// top-level shapes, and each shape must have the same number of holes (if any), and so on.
    ///
    public init(_ method: LayerInterpolation = .automatic, @LayerBuilder layers: () -> [Layer]) {
        self.interpolation = method
        self.layers = layers().sorted(by: { $0.z < $1.z })
        precondition(self.layers.count >= 2, "Loft requires at least two layers")
    }

    public typealias LayerBuilder = ArrayBuilder<Layer>

    public struct Layer: Sendable {
        internal let z: Double
        internal let geometry: any Geometry2D
    }

    /// Specifies how the layers in a lofted shape are connected.
    public enum LayerInterpolation: Sendable, Hashable, Codable {
        /// Automatically chooses the most appropriate interpolation method.
        /// Uses `.convexHull` if all layers contain a single convex polygon; otherwise falls back to `.resampled`.
        case automatic

        /// Connects layers using their convex hulls. Fast and simple, but less accurate for complex shapes.
        /// Best used when the convex hull is a good enough approximation of the desired shape.
        case convexHull

        /// Resamples each shape to have matching vertex counts. Allows precise matching of complex shapes, including those with holes.
        /// All layers must have the same topology; the same number of sub-shapes, each with matching hole counts and structure.
        ///
        /// The `ShapingFunction` parameter determines how intermediate layers are distributed and how the transition between each pair of cross-sections progresses.
        /// By default, the interpolation is linear, meaning each intermediate layer is evenly spaced in both height and shape between the source and target layers.
        ///
        /// By supplying a different shaping function, you can control the interpolation rate—such as using "ease in", "ease out", or a custom curve.
        /// This can be used to create organic bulges, tapering, or other stylized transitions between layers.
        /// See `ShapingFunction` for available built-in curves and how to create custom ones.
        ///
        case resampled (ShapingFunction)

        public static var resampled: Self { .resampled(.linear) }
    }
}

/// Creates a single layer in a lofted shape at the specified Z height.
/// This function is intended to be used inside a `Loft` builder to define each horizontal cross-section.
///
/// - Parameters:
///   - z: The Z height at which to place the 2D shape.
///   - shape: A builder that returns the 2D geometry to use for this layer.
///
public func layer(z: Double, @GeometryBuilder2D shape: () -> any Geometry2D) -> Loft.Layer {
    Loft.Layer(z: z, geometry: shape())
}

public extension Geometry2D {
    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two layers.
    ///
    /// - Parameters:
    ///   - method: The interpolation method to use. Defaults to `.automatic`, which selects an appropriate strategy based on shape complexity.
    ///   - height: The vertical distance between the two layers.
    ///   - with: A builder that returns the 2D shape to use for the second layer, placed at the specified height.
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
        _ method: Loft.LayerInterpolation = .automatic,
        height: Double,
        @GeometryBuilder2D with other: () -> any Geometry2D
    ) -> any Geometry3D {
        Loft(method) {
            layer(z: 0) { self }
            layer(z: height, shape: other)
        }
    }
}
