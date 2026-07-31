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
    func readingPoints<D: Dimensionality>(
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
    func readingSamples<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([CurveSample<V>]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(samples(segmentation: e.segmentation))
        }
    }

    /// Returns samples picked at the requested arc-length positions along the curve.
    ///
    /// The curve is first subdivided into a polyline using `segmentation` (same as `samples(segmentation:)`).
    /// The polyline's cumulative arc length is then walked to extract samples at the positions
    /// described by `interval`. Each returned sample's `position`, `tangent`, `u`, and `distance`
    /// fields are linearly interpolated from the bracketing polyline samples.
    ///
    /// - Parameters:
    ///   - interval: Where along the curve to place samples — a fixed arc-length step or a fixed count.
    ///   - segmentation: Controls the density of the underlying polyline that the samples are picked from.
    /// - Returns: A list of samples at the requested arc-length positions, in ascending order.
    ///
    func samples(at interval: CurveSampleInterval, segmentation: Segmentation) -> [CurveSample<V>] {
        let polyline = samples(segmentation: segmentation)
        guard let totalLength = polyline.last?.distance, totalLength > 0 else {
            // Degenerate curve: surface any zero-length cases. `.count(>=1, ...)` still returns the start.
            switch interval {
            case .count(let n, _) where n >= 1: return polyline.first.map { [$0] } ?? []
            default: return []
            }
        }

        let targets = interval.targetDistances(totalLength: totalLength)
        var result: [CurveSample<V>] = []
        result.reserveCapacity(targets.count)
        var cursor = 0

        for d in targets {
            if d <= 0 {
                result.append(polyline.first!)
                continue
            }
            if d >= totalLength {
                result.append(polyline.last!)
                continue
            }
            while cursor + 1 < polyline.count - 1, polyline[cursor + 1].distance < d {
                cursor += 1
            }
            let prev = polyline[cursor]
            let next = polyline[cursor + 1]
            let segmentLength = next.distance - prev.distance
            let t = segmentLength > 0 ? (d - prev.distance) / segmentLength : 0
            result.append(prev.interpolated(with: next, fraction: t))
        }
        return result
    }

    /// Picks samples at the requested arc-length positions along the curve and passes them to the reader.
    ///
    /// The underlying subdivision uses the environment's segmentation; the picked samples are
    /// independent of it. See `samples(at:segmentation:)` for the resampling rules.
    ///
    /// - Parameters:
    ///   - interval: Where along the curve to place samples — a fixed arc-length step or a fixed count.
    ///   - reader: A closure that transforms the picked samples into a geometry value.
    /// - Returns: A constructed geometry object based on the picked samples.
    ///
    func readingSamples<D: Dimensionality>(
        at interval: CurveSampleInterval,
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([CurveSample<V>]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(samples(at: interval, segmentation: e.segmentation))
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

    subscript(parameter: Double) -> V {
        point(at: parameter)
    }

    /// Returns the tangent direction at a specific position along the curve.
    ///
    /// - Parameter fraction: The position along the curve where the tangent is evaluated.
    /// - Returns: A `Direction` representing the tangent vector at the given position.
    ///
    func tangent(at fraction: Double) -> Direction<V.D> {
        derivativeView.tangent(at: fraction)
    }
}
