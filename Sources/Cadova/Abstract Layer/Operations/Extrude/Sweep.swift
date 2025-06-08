import Foundation
import Manifold3D

public extension Geometry2D {
    /// Sweeps the 2D geometry along a 3D path to create a 3D solid, using default orientation control
    ///
    /// This method extrudes the shape along a `BezierPath` in 3D space, positioning and orienting
    /// it continuously along the path to form a smooth, connected 3D body. The orientation is fixed so
    /// that the negative Y direction in the 2D shape (`.down`) always points toward the negative Z axis
    /// in 3D space. It can be used to model pipes, rails, bent sheets, or any geometry that follows a
    /// curved trajectory. The orientation is computed as an attempt to align the reference direction
    /// toward the target, but this is not always geometrically possible at every step.
    ///
    /// - Parameters:
    ///   - path: The path the shape should follow. This can be a 2D or 3D Bezier path. If 2D,
    ///     the path is interpreted as lying in the XY plane.
    /// - Returns: A 3D geometry created by sweeping the shape along the path.
    ///
    /// The shape is placed along a series of points on the path, with consistent orientation and twisting
    /// to minimize sharp transitions. The spacing and number of sample points along the path is determined
    /// by the environment’s segmentation settings. This affects the smoothness and polygon count of the
    /// resulting geometry. The twist rate is controlled by the ``EnvironmentValues/maxTwistRate``
    /// setting, which limits the rate of rotation between successive frames.
    ///
    /// - SeeAlso: ``Geometry/withMaxTwistRate(_:)``
    func swept<V: Vector>(along path: BezierPath<V>) -> any Geometry3D {
        Sweep(shape: self, path: path.path3D, reference: .negativeY, target: .direction(.negativeZ))
    }

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
    ///   - direction: The direction that the `reference` direction should point toward at every step of the path.
    /// - Returns: A 3D geometry created by sweeping the shape along the path, with orientation guided by the `reference` and `target`.
    ///
    /// The shape is placed along a series of points on the path, with consistent orientation and twisting
    /// to minimize sharp transitions. The `reference` and `direction` let you control which way the shape is "facing"
    /// as it travels, allowing for effects like keeping the bottom of a rail always pointing down. The orientation is computed
    /// as an attempt to align the reference direction toward the target, but this is not always geometrically possible at every step.
    ///
    /// The spacing and number of sample points along the path is determined by the environment’s segmentation settings.
    /// This affects the smoothness and polygon count of the resulting geometry. The twist rate is controlled by the
    /// ``EnvironmentValues/maxTwistRate`` setting, which limits the rate of rotation between successive frames.
    ///
    /// - SeeAlso: ``Geometry/withMaxTwistRate(_:)``
    func swept<V: Vector>(along path: BezierPath<V>, pointing reference: Direction2D, toward direction: Direction3D) -> any Geometry3D {
        Sweep(shape: self, path: path.path3D, reference: reference, target: .direction(direction))
    }

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
    ///   - point: The fixed 3D point that the `reference` direction should point toward at every step of the path.
    /// - Returns: A 3D geometry created by sweeping the shape along the path, with orientation guided by the `reference` and `point`.
    ///
    /// The shape is placed along a series of points on the path, with consistent orientation and twisting
    /// to minimize sharp transitions. The `reference` and `point` let you control which way the shape is "facing"
    /// as it travels, allowing for effects like keeping the bottom of a rail always pointing toward a target point. The orientation is
    /// computed as an attempt to align the reference direction toward the target, but this is not always geometrically possible at every step.
    ///
    /// The spacing and number of sample points along the path is determined by the environment’s segmentation settings.
    /// This affects the smoothness and polygon count of the resulting geometry. The twist rate is controlled by the
    /// ``EnvironmentValues/maxTwistRate`` setting, which limits the rate of rotation between successive frames.
    ///
    /// - SeeAlso: ``Geometry/withMaxTwistRate(_:)``
    func swept<V: Vector>(along path: BezierPath<V>, pointing reference: Direction2D, toward point: Vector3D) -> any Geometry3D {
        Sweep(shape: self, path: path.path3D, reference: reference, target: .point(point))
    }

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
    ///   - line: The 3D line that the `reference` direction should point toward at every step of the path.
    /// - Returns: A 3D geometry created by sweeping the shape along the path, with orientation guided by the `reference` and `line`.
    ///
    /// The shape is placed along a series of points on the path, with consistent orientation and twisting
    /// to minimize sharp transitions. The `reference` and `line` let you control which way the shape is "facing"
    /// as it travels, allowing for effects like keeping the bottom of a rail always facing a spatial axis. The orientation is computed
    /// as an attempt to align the reference direction toward the target, but this is not always geometrically possible at every step.
    ///
    /// The spacing and number of sample points along the path is determined by the environment’s segmentation settings.
    /// This affects the smoothness and polygon count of the resulting geometry. The twist rate is controlled by the
    /// ``EnvironmentValues/maxTwistRate`` setting, which limits the rate of rotation between successive frames.
    ///
    /// - SeeAlso: ``Geometry/withMaxTwistRate(_:)``
    func swept<V: Vector>(along path: BezierPath<V>, pointing reference: Direction2D, toward line: D3.Line) -> any Geometry3D {
        Sweep(shape: self, path: path.path3D, reference: reference, target: .line(line))
    }
}

internal struct Sweep: Shape3D {
    let shape: any Geometry2D
    let path: BezierPath3D
    let reference: Direction2D
    let target: BezierPath3D.FrameTarget

    @Environment(\.maxTwistRate) var maxTwistRate
    @Environment(\.segmentation) var segmentation

    var body: any Geometry3D {
        CachedNodeTransformer(body: shape, name: "sweep", parameters: path, reference, target, maxTwistRate, segmentation) { node, environment, context in
            let crossSection = try await context.result(for: node).concrete
            let (frames, _) = path.frames(
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
