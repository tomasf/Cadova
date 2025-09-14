import Foundation
import Manifold3D

public extension Geometry2D {
    /// Sweeps the 2D geometry along a 3D path to create a 3D solid.
    ///
    /// This method extrudes the shape along a `BezierPath` in 3D space, positioning and orienting
    /// it continuously along the path to form a smooth, connected 3D body. It can be used to model
    /// pipes, rails, bent sheets, or any geometry that follows a curved trajectory.
    ///
    /// - Parameters:
    ///   - path: The path the shape should follow. This can be a 2D or 3D Bezier path. If 2D,
    ///     the path is interpreted as lying in the XY plane.
    ///   - reference: A direction within the 2D shape (usually `.down` or `.right`) that should be
    ///     kept facing toward the `target` during the sweep. This affects the rotation of the shape
    ///     as it travels along the path.
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
    func swept<V: Vector>(
        along path: BezierPath<V>,
        pointing reference: Direction2D = .negativeY,
        toward target: ReferenceTarget = .direction(.negativeZ)
    ) -> any Geometry3D {
        Sweep(shape: self, path: path.path3D, reference: reference, target: target)
    }
}

internal struct Sweep: Shape3D {
    let shape: any Geometry2D
    let path: BezierPath3D
    let reference: Direction2D
    let target: ReferenceTarget

    var body: any Geometry3D {
        @Environment(\.maxTwistRate) var maxTwistRate
        @Environment(\.segmentation) var segmentation

        CachedNodeTransformer(
            body: shape, name: "sweep", parameters: path, reference, target, maxTwistRate, segmentation
        ) { node, environment, context in
            let crossSection = try await context.result(for: node).concrete
            let frames = path.frames(
                environment: environment,
                target: target,
                targetReference: reference,
                perpendicularBounds: .init(crossSection.bounds)
            )
            let mesh = Mesh(extruding: crossSection.polygonList(), along: frames.map(\.transform))
            return GeometryNode.shape(.mesh(mesh.meshData))
        }
    }
}
