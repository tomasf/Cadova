import Foundation
import Manifold3D

public extension Geometry {
    /// Refines the geometry by subdividing edges or segments to ensure no edge exceeds the specified maximum length.
    ///
    /// This operation increases the resolution of both 2D and 3D geometries by inserting additional points along
    /// long edges or segments. It ensures that no individual edge (in 3D) or segment (in 2D) exceeds the specified
    /// `maxEdgeLength`.
    ///
    /// Refinement is particularly useful for preparing geometries for non-linear transformations such as
    /// warping, wrapping, or other deformation operations where a higher density of points results in a smoother output.
    ///
    /// - Parameter maxEdgeLength: The maximum allowed length of any edge or segment after refinement.
    /// - Returns: A new geometry with refined resolution, adapted to the specified maximum edge length.
    ///
    func refined(maxEdgeLength: Double) -> D.Geometry {
        return CachingPrimitiveTransformer(body: self, name: "Cadova.Refine", parameters: maxEdgeLength) {
            $0.refine(edgeLength: maxEdgeLength)
        }
    }
}

public extension Geometry {
    /// Returns a simplified version of the geometry by reducing unnecessary detail.
    ///
    /// This operation removes redundant vertices or triangles from the geometry, based on the specified `epsilon` threshold.
    /// Vertices that are closer together than `epsilon`, or that are nearly collinear with their neighbors, are candidates for removal.
    /// Increasing the `epsilon` value makes the simplification more aggressive, potentially removing more features at the cost of fidelity.
    ///
    /// Applying simplification can significantly improve performance for subsequent operations by reducing complexity without noticeably altering the shape.
    ///
    /// - Parameters:
    ///   - tolerance: The minimum distance threshold for simplification. Smaller values preserve more detail; larger values produce simpler geometry.
    ///
    /// - Returns:
    ///   A new, simplified geometry instance.
    ///
    func simplified(tolerance: Double) -> D.Geometry {
        CachingPrimitiveTransformer(body: self, name: "Cadova.Simplify", parameters: tolerance) { primitive in
            primitive.simplify(epsilon: tolerance)
        }
    }
}
