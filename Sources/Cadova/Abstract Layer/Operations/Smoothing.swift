import Foundation

public extension Geometry3D {
    /// Softens hard edges and corners to make a model look more rounded.
    ///
    /// Think of this as an "overall softness" control:
    /// - `0`: no change
    /// - around `0.2...0.4`: subtle edge softening
    /// - around `0.6...1`: strong smoothing with visibly rounder forms
    ///
    /// - Parameters:
    ///   - strength: Overall smoothing amount from `0` (unchanged) to `1` (maximum smoothing).
    /// - Returns: A new geometry with smoother transitions between faces.
    func smoothed(strength: Double) -> any Geometry3D {
        precondition(strength >= 0 && strength <= 1, "Smoothing strength must be in range 0...1")
        guard strength > .ulpOfOne else { return self }

        return measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let maxDimension = max(bounds.size.x, max(bounds.size.y, bounds.size.z))
            let segmentCount = segmentation.segmentCount(length: maxDimension)
            let maxEdgeLength = maxDimension / Double(segmentCount)
            let defaultMinSharpAngle = 60.0

            GeometryNodeTransformer(body: geometry) {
                .refine(
                    .smoothOut($0, minSharpAngle: defaultMinSharpAngle, minSmoothness: strength),
                    maxEdgeLength: maxEdgeLength
                )
            }
        }
    }
}
