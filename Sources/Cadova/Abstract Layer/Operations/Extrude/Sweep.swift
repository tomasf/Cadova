import Foundation
import Manifold3D

public extension Geometry2D {
    /// Sweeps the 2D geometry along a 3D path to create a 3D solid.
    ///
    /// This method extrudes the shape along a `ParametricCurve` in 3D space, positioning and orienting
    /// it continuously along the path to form a smooth, connected 3D body. It can be used to model
    /// pipes, rails, bent sheets, or any geometry that follows a curved trajectory.
    ///
    /// - Parameters:
    ///   - path: The path the shape should follow. This can be a 2D or 3D parametric curve. If 2D,
    ///     the path is interpreted as lying in the XY plane.
    ///   - reference: A direction within the 2D shape (usually `.down` or `.right`) that should be
    ///     kept facing toward the `target` during the sweep. This affects the rotation of the shape
    ///     as it travels along the path. There's no universally sensible default: what's natural for
    ///     a roughly-horizontal path (e.g. facing gravity-down) can be degenerate for a vertical one,
    ///     so this must be specified explicitly.
    ///   - target: The 3D direction, point, or line that the `reference` direction should point toward
    ///     at every step of the path. This controls the orientation of the shape as it sweeps.
    /// - Returns: A 3D geometry created by sweeping the shape along the path, with orientation guided
    ///   by the `reference` and `target`.
    ///
    /// The shape is placed along a series of points on the path, with consistent orientation and twisting
    /// to minimize sharp transitions. The orientation is computed as an attempt to align the reference
    /// direction toward the target, but this is not always geometrically possible at every step.
    ///
    /// The spacing and number of sample points along the path is determined by the environment’s
    /// segmentation settings. This affects the smoothness and polygon count of the resulting geometry.
    /// The twist rate is controlled by the ``EnvironmentValues/maxTwistRate`` setting, which limits the
    /// rate of rotation between successive frames.
    ///
    /// - SeeAlso: ``Geometry/withMaxTwistRate(_:)``
    func swept<Path: ParametricCurve>(
        along path: Path,
        pointing reference: Direction2D,
        toward target: ReferenceTarget
    ) -> any Geometry3D {
        Sweep(shape: self, path: path, reference: reference, target: target)
    }

    /// Sweeps the 2D geometry along a 3D path to create a 3D solid, using the default orientation
    /// (facing gravity-down as the path allows).
    ///
    /// - Parameter path: The path the shape should follow. This can be a 2D or 3D parametric curve.
    ///   If 2D, the path is interpreted as lying in the XY plane.
    /// - Returns: A 3D geometry created by sweeping the shape along the path.
    ///
    /// - SeeAlso: ``swept(along:pointing:toward:)``
    @available(*, deprecated, message: "Specify pointing and toward explicitly — the previous default (.negativeY, .direction(.negativeZ)) can be degenerate for non-horizontal paths")
    func swept<Path: ParametricCurve>(along path: Path) -> any Geometry3D {
        swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))
    }
}

internal struct Sweep<Path: ParametricCurve>: Geometry3D {
    let shape: any Geometry2D
    let path: Path
    let reference: Direction2D
    let target: ReferenceTarget

    var body: any Geometry3D {
        @Environment(\.maxTwistRate) var maxTwistRate
        @Environment(\.scaledSegmentation) var segmentation

        CachedNodeTransformer(
            source: shape, name: "sweep", parameters: path, reference, target, maxTwistRate, segmentation
        ) { node, environment, context in
            let crossSection = try await context.result(for: node).concrete
            let frames = path.curve3D.frames(
                environment: environment,
                target: target,
                targetReference: reference,
                perpendicularBounds: .init(crossSection.bounds),
                miteringCorners: true
            )
            let mesh = Mesh(
                extruding: crossSection.polygonList(),
                along: frames.map(\.transform),
                cacheName: "Sweep"
            )
            return GeometryNode.shape(.mesh(mesh.meshData))
        }
    }
}
