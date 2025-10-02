import Foundation

public extension ParametricCurve {
    /// This method computes a smooth sequence of `Transform3D` values that follow the curve in 3D,
    /// controlling orientation and twist based on a specified reference direction and a target (point, line, or direction).
    /// These transforms can be used to position and orient geometry along a path, such as placing cross-sections for a sweep.
    ///
    /// The orientation is guided by the `reference` direction, which is defined in the local 2D coordinate system of a plane perpendicular
    /// to the path at each point. The transform attempts to keep this direction facing the `target` in global 3D space.
    ///
    /// The generated transforms account for the environment’s segmentation and maximum twist rate.
    ///
    /// - Parameters:
    ///   - reference: A direction defined in the 2D plane perpendicular to the curve, which will be kept facing the target direction
    ///     or point.
    ///   - target: A `ReferenceTarget` (point, line, or direction) that the `reference` direction should face along the curve.
    ///   - reader: A closure that receives the full list of computed transforms and produces a 3D geometry.
    /// - Returns: A 3D geometry built from the transforms along the curve.
    ///
    func readingTransforms(
        pointing reference: Direction2D = .down,
        toward target: ReferenceTarget = .direction(.down),
        @GeometryBuilder3D reader: @Sendable @escaping ([Transform3D]) -> any Geometry3D
    ) -> any Geometry3D {
        readEnvironment { environment in
            let frames = curve3D.frames(environment: environment, target: target, targetReference: reference, perpendicularBounds: .zero)
            return reader(frames.map(\.transform))
        }
    }
}
