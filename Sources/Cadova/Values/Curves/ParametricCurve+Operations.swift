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

    /// Converts a sequence of points along the curve into a custom geometry using a geometry builder.
    ///
    /// - Parameters:
    ///   - reader: A closure that transforms points into a geometry value.
    /// - Returns: A constructed geometry object based on the sampled points.
    ///
    func readPoints<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([V]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(points(segmentation: e.segmentation))
        }
    }

    /// Converts a sequence of samples along the curve into a custom geometry using a geometry builder.
    ///
    /// - Parameters:
    ///   - reader: A closure that transforms samples into a geometry value.
    /// - Returns: A constructed geometry object based on the samples.
    ///
    func readSamples<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([CurveSample<V>]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(samples(segmentation: e.segmentation))
        }
    }

    var approximateLength: Double {
        length(segmentation: .fixed(sampleCountForLengthApproximation))
    }

    var curve3D: Curve3D {
        switch self {
        case let self as Curve3D: self
        default: mapPoints(\.vector3D)
        }
    }

    /// Applies an affine transform to all control points (weights unchanged).
    func transformed(using transform: V.D.Transform) -> Self where Self == Curve2D {
        mapPoints(transform.apply(to:))
    }

    /// Applies an affine transform to all control points (weights unchanged).
    func transformed(using transform: V.D.Transform) -> Self where Self == Curve3D {
        mapPoints(transform.apply(to:))
    }

    subscript(parameter: Double) -> V {
        point(at: parameter)
    }

    /// Returns the tangent direction at a specific position along the curve.
    ///
    /// - Parameter parameter: The position along the curve where the tangent is evaluated.
    /// - Returns: A `Direction` representing the tangent vector at the given position.
    ///
    func tangent(at fraction: Double) -> Direction<V.D> {
        derivativeView.tangent(at: fraction)
    }
}
