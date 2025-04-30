import Foundation
import Manifold3D

public struct LevelSet: CompositeGeometry {
    public typealias D = D3

    let function: @Sendable (Vector3D) -> Double
    let bounds: BoundingBox3D
    let edgeLength: Double
    let level: Double
    let tolerance: Double?
    let cacheKey: NamedCacheKey

    /// Constructs a 3D mesh by sampling a Signed Distance Function (SDF) over a volume.
    ///
    /// This shape represents the *level set* of a scalar field — typically the zero level — and
    /// can be used to model smooth, organic surfaces like metaballs or procedurally defined volumes.
    /// Internally, it uses the [Marching Tetrahedra](https://en.wikipedia.org/wiki/Marching_tetrahedra)
    /// algorithm on a body-centered cubic grid to extract a manifold surface.
    ///
    /// This is a computationally intensive operation that evaluates the SDF across a dense 3D grid,
    /// so it should be used for shapes that benefit from smooth isosurfaces and procedural complexity.
    ///
    /// - Parameters:
    ///   - bounds: The bounding box within which to evaluate the SDF.
    ///   - edgeLength: Controls the density of the sampling grid. Smaller values yield finer meshes but are more computationally expensive.
    ///   - level: The threshold value at which to extract the surface from the SDF. Defaults to `0`.
    ///   - tolerance: Optional precision hint that adjusts how closely vertices must lie to the exact isosurface.
    ///               If omitted, a heuristic based on grid resolution is used.
    ///   - name: A string identifying the transformation operation. Used as part of the cache key.
    ///   - cacheParameters: Optional parameters that further define the transformation. These should be values that uniquely
    ///   describe the warp operation so that results can be cached correctly.
    ///   - sdf: A closure that returns the signed distance at a given point in 3D space. Positive values are considered *inside* the surface, and negative values *outside*.
    ///
    /// - Important: While the SDF does not have to be continuous or even a true distance function, discontinuities or poor sampling resolution may produce jagged or incorrect surfaces.
    public init(
        bounds: BoundingBox3D,
        edgeLength: Double,
        level: Double = 0,
        tolerance: Double? = nil,
        name: String,
        cacheParameters: any Hashable & Sendable & Codable...,
        sdf: @Sendable @escaping (Vector3D) -> Double
    ) {
        self.function = sdf
        self.bounds = bounds
        self.edgeLength = edgeLength
        self.level = level
        self.tolerance = tolerance

        cacheKey = NamedCacheKey(operationName: name, parameters: cacheParameters)
    }

    public var body: D3.Geometry {
        CachingPrimitive(key: cacheKey) {
            .levelSet(
                bounds: (bounds.minimum, bounds.maximum),
                edgeLength: edgeLength,
                level: level,
                tolerance: tolerance ?? -1
            ){ function($0.vector3D) }
        }
    }
}
