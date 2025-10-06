import Foundation

public extension Geometry {
    /// Applies a given affine transformation to the geometry.
    /// - Parameter transform: The transformation to be applied.
    /// - Returns: A transformed `Geometry`.
    func transformed(_ transform: D.Transform) -> D.Geometry {
        GeometryNodeTransformer(body: self) {
            .transform($0, transform: transform)
        } environment: {
            $0.applyingTransform(transform.transform3D)
        }
        .modifyingResult(PartCatalog.self) {
            $0 = $0.applyingTransform(transform.transform3D)
        }
    }
}
